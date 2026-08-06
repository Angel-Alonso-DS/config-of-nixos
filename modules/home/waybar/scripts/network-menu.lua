#!/usr/bin/env lua
-- Menú de red Wi-Fi vía nmcli + rofi -dmenu. Migrado desde walker --dmenu
-- tras la eliminación completa de Walker/elephant.

local function shell(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function list_networks()
  -- --rescan no: sin esto, nmcli dispara un rescan activo si el último
  -- fue hace >30s, y con el chip RTL8852BE eso puede tardar varios
  -- segundos — es la causa más probable de la lentitud reportada.
  -- TRADE-OFF real: la lista puede no incluir redes nuevas que aparecieron
  -- en los últimos segundos. Si necesitas ver una red recién prendida,
  -- agrega el bind SUPER+SHIFT+R (o el que uses) a `nmcli device wifi
  -- rescan` por separado, sin bloquear el menú.
  local output = shell("nmcli -t -f SSID,SECURITY,SIGNAL device wifi list --rescan no")
  local networks = {}
  local seen = {}
  for line in output:gmatch("[^\n]+") do
    local ssid, security, signal = line:match("^(.-):(.-):(%d+)$")
    if ssid and ssid ~= "" and not seen[ssid] then
      seen[ssid] = true
      table.insert(networks, { ssid = ssid, security = security, signal = tonumber(signal) })
    end
  end
  return networks
end

local function rofi_select(lines, prompt)
  local input = table.concat(lines, "\n")
  local handle = io.popen("printf '%s' " .. shell_quote(input) .. " | rofi -dmenu -p " .. shell_quote(prompt))
  local selection = handle:read("*l")
  handle:close()
  return selection
end

local function is_known_connection(ssid)
  local output = shell("nmcli -t -f NAME connection show")
  for name in output:gmatch("[^\n]+") do
    if name == ssid then return true end
  end
  return false
end

local function prompt_password_via_rofi(ssid)
  -- -password: NO confirmado con ejemplo literal en esta sesión, es
  -- flag histórico muy conocido de scripts de lockscreen con rofi.
  -- Verificar con `rofi -help | grep -i pass` antes de confiar del todo.
  local handle = io.popen("rofi -dmenu -password -p " .. shell_quote("Contraseña: " .. ssid))
  local password = handle:read("*l")
  handle:close()
  return password
end

local function connect(network)
  local open_network = network.security == "" or network.security == "--"
  if open_network or is_known_connection(network.ssid) then
    os.execute(string.format("nmcli device wifi connect '%s'", network.ssid))
  else
    local password = prompt_password_via_rofi(network.ssid)
    if not password or password == "" then return end
    os.execute(string.format("nmcli device wifi connect '%s' password '%s'", network.ssid, password))
  end
end

local function prompt_text_via_rofi(prompt)
  local handle = io.popen("rofi -dmenu -p " .. shell_quote(prompt))
  local text = handle:read("*l")
  handle:close()
  return text
end

local function get_wifi_ifname()
  -- Detecta el nombre real de la interfaz Wi-Fi (wlan0, wlp0s20f3, etc.
  -- varía por sistema) en vez de asumir un nombre fijo.
  local output = shell("nmcli -t -f DEVICE,TYPE device")
  for line in output:gmatch("[^\n]+") do
    local dev, kind = line:match("^(.-):(.+)$")
    if kind == "wifi" then return dev end
  end
  return nil
end

local function is_hotspot_active()
  local active = shell("nmcli -t -f NAME connection show --active")
  for name in active:gmatch("[^\n]+") do
    if name == "Hotspot" then return true end
  end
  return false
end

local function stop_hotspot()
  os.execute("nmcli connection down Hotspot")
end

local function create_hotspot()
  local ifname = get_wifi_ifname()
  if not ifname then
    io.stderr:write("No se encontró interfaz Wi-Fi.\n")
    return
  end

  local ssid = prompt_text_via_rofi("SSID del punto de acceso")
  if not ssid or ssid == "" then return end

  local password = prompt_password_via_rofi(ssid)
  if not password or password == "" then return end

  -- WPA2 exige mínimo 8 caracteres — nmcli falla con un error críptico
  -- si no, mejor avisarlo directo acá.
  if #password < 8 then
    os.execute("notify-send 'Punto de acceso' 'La contraseña debe tener al menos 8 caracteres' -u critical")
    return
  end

  -- con-name explícito ("Hotspot") para poder detenerlo después con
  -- certeza — sin esto, el nombre por defecto varía entre versiones
  -- de NetworkManager y no podríamos ubicarlo de forma confiable.
  os.execute(string.format(
    "nmcli device wifi hotspot ifname %s con-name Hotspot ssid %s password %s",
    shell_quote(ifname), shell_quote(ssid), shell_quote(password)
  ))
end

local function main()
  local networks = list_networks()

  table.sort(networks, function(a, b) return a.signal > b.signal end)

  local lines = {}
  for i, n in ipairs(networks) do
    local lock = (n.security ~= "" and n.security ~= "--") and "󰌾" or "  "
    lines[i] = string.format("%s %3d%%  %s", lock, n.signal, n.ssid)
  end

  local hotspot_active = is_hotspot_active()
  local hotspot_index = #lines + 1
  lines[hotspot_index] = hotspot_active and " Detener punto de acceso" or "󱄙 Crear punto de acceso"

  local selection = rofi_select(lines, "Wi-Fi")
  if not selection then return end

  if selection == lines[hotspot_index] then
    if hotspot_active then
      stop_hotspot()
    else
      create_hotspot()
    end
    return
  end

  for i, line in ipairs(lines) do
    if i ~= hotspot_index and line == selection then
      connect(networks[i])
      break
    end
  end
end

main()
