#!/usr/bin/env lua
-- hotspot-menu.lua
-- Menú único de administración del hotspot (NetworkManager + rofi).

local WIFI_IFACE = "wlo1"  -- fijo: es la interfaz dedicada al hotspot

local function is_active()
  local out = shell("systemctl is-active hotspot.target 2>/dev/null")
  return out:match("^active") ~= nil
end

local function get_ssid()
  local f = io.open("/etc/hotspot-ssid", "r")
  if not f then return "?" end
  local s = f:read("*l")
  f:close()
  return s or "?"
end

local function toggle_hotspot(active)
  if active then
    os.execute("systemctl stop hotspot.target")
  else
    os.execute("systemctl start hotspot.target")
  end
end

local function shell(cmd)
  local h = io.popen(cmd)
  local out = h:read("*a")
  h:close()
  return out
end

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function rofi_select(lines, prompt, mesg)
  local input = table.concat(lines, "\n")
  local mesg_flag = mesg and (" -mesg " .. shell_quote(mesg)) or ""
  local cmd = "printf '%s' " .. shell_quote(input)
    .. " | rofi -dmenu -p " .. shell_quote(prompt) .. mesg_flag
  local h = io.popen(cmd)
  local sel = h:read("*l")
  h:close()
  return sel
end

-- Best-effort: nombre de host desde el archivo de leases del dnsmasq
-- interno de NetworkManager. Si no existe o no es legible, se ignora
-- sin romper el flujo (no usamos sudo para esto).
local function read_hostnames()
  local hosts = {}
  local ok, f = pcall(io.open, "/var/lib/NetworkManager/dnsmasq-" .. (WIFI_IFACE or "") .. ".leases", "r")
  if ok and f then
    for line in f:lines() do
      local mac, ip, name = line:match("^%d+%s+(%S+)%s+(%S+)%s+(%S+)")
      if mac then hosts[mac:lower()] = (name ~= "*" and name or nil) end
    end
    f:close()
  end
  return hosts
end

-- Lista de clientes vía `ip neigh` (no requiere privilegios, a
-- diferencia de `iw station dump`).
local function get_clients(ifname)
  local hosts = read_hostnames()
  local clients = {}
  local out = shell("ip neigh show dev " .. shell_quote(ifname) .. " 2>/dev/null")
  for line in out:gmatch("[^\n]+") do
    local ip, mac, state = line:match("^(%S+)%s+lladdr%s+(%S+)%s+(%a+)$")
    if ip and mac and (state == "REACHABLE" or state == "STALE" or state == "DELAY" or state == "PERMANENT") then
      table.insert(clients, {
        ip = ip, mac = mac, state = state,
        name = hosts[mac:lower()] or "(sin nombre)"
      })
    end
  end
  return clients
end

local function clients_menu(ifname)
  local clients = get_clients(ifname)
  local lines = {}
  for i, c in ipairs(clients) do
    lines[i] = string.format("%s  |  %s  |  %s  |  %s", c.name, c.ip, c.mac, c.state)
  end
  local back = "← Volver"
  table.insert(lines, back)
  if #clients == 0 then
    table.insert(lines, 1, "(sin clientes conectados)")
  end

  rofi_select(lines, "Clientes", string.format("Interfaz: %s", ifname))
end

local function main()
  local ifname = WIFI_IFACE
  if not ifname then
    os.execute("notify-send 'Hotspot' 'No se encontró interfaz Wi-Fi' -u critical")
    return
  end

  while true do
    local active = is_active()
    local ssid = active and get_ssid() or "-"
    local clients = active and get_clients(ifname) or {}

    local status_icon = active and "🟢 ACTIVO" or "🔴 INACTIVO"
    local mesg = string.format("Hotspot: %s   SSID: %s   Interfaz: %s   Clientes: %d",
      status_icon, ssid, ifname, #clients)

    local toggle_label = active and "🔌 Desactivar hotspot" or "📡 Activar hotspot"
    local options = {
      toggle_label,
      "👥 Ver dispositivos conectados",
      "🔄 Actualizar",
      "✕ Salir",
    }

    local sel = rofi_select(options, "Zona de red", mesg)
    if not sel or sel == "✕ Salir" then break end

    if sel == toggle_label then
      toggle_hotspot(active)
      os.execute("sleep 1") -- deja que NM aplique el cambio antes de refrescar
    elseif sel == "👥 Ver dispositivos conectados" then
      clients_menu(ifname)
    end
    -- "🔄 Actualizar" simplemente vuelve a iterar el while
  end
end

main()
