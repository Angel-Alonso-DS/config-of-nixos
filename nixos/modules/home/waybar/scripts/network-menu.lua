#!/usr/bin/env lua
-- network-menu.lua — menú de Wi-Fi vía nmcli (NetworkManager). Sin hotspot.
--
-- Enter      : conectar. Sobre la red actual abre sus opciones.
-- Alt+Enter  : opciones de la red (conectar/desconectar, olvidar).
-- Esc        : en un submenú vuelve al anterior; en el menú principal sale.
--
-- El candado marca redes que pedirán contraseña (no guardadas y protegidas).
-- Orden: actual, guardadas, resto por señal.
--
-- Limitación de nmcli: la contraseña de una red nueva viaja como argumento
-- de `nmcli device wifi connect` y es visible en `ps` durante ~1 segundo
-- para otros usuarios de este equipo.

local ui
do
  local self = (arg and arg[0]) or ""
  package.path = (self:match("^(.*)/") or ".") .. "/?.lua;" .. package.path
  local ok, mod = pcall(require, "menu-common")
  if not ok then -- script enlazado (symlink): buscar junto al archivo real
    local h = io.popen("readlink -f '" .. self:gsub("'", "'\\''") .. "' 2>/dev/null")
    local real = h and h:read("l") or ""
    if h then h:close() end
    package.path = (real:match("^(.*)/") or ".") .. "/?.lua;" .. package.path
    ok, mod = pcall(require, "menu-common")
    if not ok then io.stderr:write(tostring(mod) .. "\n"); os.exit(1) end
  end
  ui = mod
end
local I = ui.icons

-- ─── Configuración ─────────────────────────────────────────────────────────
local IFACE = nil            -- p. ej. "wlan0". nil = autodetectar.
local EXCLUDE_IFACES = {}    -- p. ej. { "wlo1" } si esa interfaz es exclusiva del hotspot.
local CONNECT_TIMEOUT = 25   -- segundos que espera nmcli al activar una conexión.
local RESCAN_WAIT = 3        -- segundos que se espera tras pedir un rescan.
local TITLE = "Wi-Fi"

-- ─── nmcli ─────────────────────────────────────────────────────────────────

local function nm(args, timeout)
  return ui.run("nmcli " .. args, { c_locale = true, timeout = timeout or 10 })
end

local ERROR_MESSAGES = {
  { "secrets were required",         "contraseña incorrecta" },
  { "no network with ssid",          "red no encontrada (¿fuera de alcance?)" },
  { "networkmanager is not running", "NetworkManager no está en ejecución" },
  { "wi-fi is disabled",             "el Wi-Fi está apagado" },
  { "wireless is disabled",          "el Wi-Fi está apagado" },
  { "not authorized",                "sin permisos (polkit)" },
  { "insufficient privileges",       "sin permisos (polkit)" },
  { "timeout expired",               "tiempo de espera agotado" },
  { "no suitable device",            "no hay una interfaz Wi-Fi disponible" },
}

local function explain(res)
  if res.timed_out then return "tiempo de espera agotado" end
  local text = res.err .. "\n" .. res.out
  local low = text:lower()
  for _, e in ipairs(ERROR_MESSAGES) do
    if low:find(e[1], 1, true) then return e[2] end
  end
  return ui.errmsg(res, "error desconocido")
end

local function is_bad_password(res)
  return (res.err .. res.out):lower():find("secrets were required", 1, true) ~= nil
end

local function fail(detail)
  ui.notify(TITLE, detail, { urgent = true, tag = "net" })
end

local function is_excluded(name)
  for _, x in ipairs(EXCLUDE_IFACES) do if x == name then return true end end
  return false
end

-- Elige la interfaz Wi-Fi: la configurada, o la primera (conectada primero).
local function find_wifi_device()
  local res = nm("-t -e no -f DEVICE,TYPE,STATE,CONNECTION device status", 5)
  if not res.ok then return nil, explain(res) end
  local best
  for line in res.out:gmatch("[^\n]+") do
    local dev, typ, state, conn = line:match("^(.-):(.-):(.-):(.*)$")
    if typ == "wifi" and not is_excluded(dev) and (not IFACE or dev == IFACE) then
      local d = { name = dev, state = state, conn = conn }
      if not best or (state:find("^connected") and not best.state:find("^connected")) then
        best = d
      end
    end
  end
  if not best then return nil, "No se encontró una interfaz Wi-Fi" end
  return best
end

local function wifi_enabled()
  return nm("radio wifi", 5).out:find("^enabled") ~= nil
end

-- Lista de redes. Con `-e no` los ':' del SSID no se escapan; como el SSID es
-- el ÚLTIMO campo, se toma "todo lo que queda" y el parseo es inequívoco.
local function list_networks(ifname)
  local res = nm("-t -e no -f IN-USE,SIGNAL,SECURITY,SSID device wifi list ifname "
    .. ui.quote(ifname) .. " --rescan no", 10)
  if not res.ok then return nil, explain(res) end

  local by_ssid, list = {}, {}
  for line in res.out:gmatch("[^\n]+") do
    local inuse, sig, sec, ssid = line:match("^(.-):(%d+):(.-):(.*)$")
    if ssid and ssid ~= "" then
      sig = tonumber(sig)
      local n = by_ssid[ssid]
      if not n then
        n = { ssid = ssid, signal = sig, security = sec, in_use = false }
        by_ssid[ssid] = n
        list[#list + 1] = n
      elseif sig > n.signal then
        n.signal, n.security = sig, sec -- varios AP con el mismo SSID: el más fuerte
      end
      if inuse == "*" then n.in_use = true end
    end
  end

  for _, n in ipairs(list) do
    local sec = n.security
    n.enterprise = sec:find("802.1X", 1, true) ~= nil
    n.secured = sec ~= "" and sec ~= "--" and not sec:find("^OWE")
  end
  return list
end

-- Perfiles Wi-Fi guardados, por SSID REAL (no por nombre de perfil, que puede
-- ser cualquier cosa). Devuelve { [ssid] = { uuid, ... } }.
local SAVED_SCRIPT = [[
nmcli -t -e no -f UUID,TYPE connection show | while IFS=: read -r u t; do
  if [ "$t" = "802-11-wireless" ]; then
    printf '%s\t%s\n' "$u" "$(nmcli -e no -g 802-11-wireless.ssid connection show uuid "$u")"
  fi
done
]]

local function saved_profiles()
  local res = ui.run(SAVED_SCRIPT, { c_locale = true, timeout = 15 })
  local saved = {}
  for line in res.out:gmatch("[^\n]+") do
    local uuid, ssid = line:match("^([%x%-]+)\t(.*)$")
    if uuid and ssid ~= "" then
      saved[ssid] = saved[ssid] or {}
      table.insert(saved[ssid], uuid)
    end
  end
  return saved
end

local function uuid_set(saved)
  local set = {}
  for _, uuids in pairs(saved) do for _, u in ipairs(uuids) do set[u] = true end end
  return set
end

-- ─── Presentación ──────────────────────────────────────────────────────────

local function signal_icon(s)
  if s <= 25 then return I.wifi_1 end
  if s <= 50 then return I.wifi_2 end
  if s <= 75 then return I.wifi_3 end
  return I.wifi_4
end

local function security_label(n)
  if n.enterprise then return "802.1X" end
  if not n.secured then return "abierta" end
  return n.security
end

-- ─── Acciones ──────────────────────────────────────────────────────────────

local function ask_password(n)
  local pw = ui.input("Contraseña", { password = true, mesg = ui.esc(n.ssid) })
  if not pw or pw == "" then return nil end
  if n.security:find("WPA", 1, true) and (#pw < 8 or #pw > 64) then
    fail("La contraseña WPA debe tener entre 8 y 63 caracteres")
    return nil
  end
  return pw
end

local function activate_saved(dev, uuid)
  return nm("-w " .. CONNECT_TIMEOUT .. " connection up uuid " .. ui.quote(uuid)
    .. " ifname " .. ui.quote(dev.name), CONNECT_TIMEOUT + 10)
end

local function delete_profiles(uuids)
  local all_ok, last = true, nil
  for _, u in ipairs(uuids) do
    local r = nm("connection delete uuid " .. ui.quote(u), 10)
    if not r.ok then all_ok, last = false, r end
  end
  return all_ok, last
end

local function forget_network(n, uuids)
  local ok, res = delete_profiles(uuids)
  if ok then
    ui.notify(TITLE, "Red olvidada: " .. n.ssid, { tag = "net" })
  else
    fail("No se pudo olvidar «" .. n.ssid .. "»: " .. explain(res))
  end
end

-- Red guardada que falló por contraseña: reintroducirla u olvidar la red.
local function bad_password_menu(dev, n, uuids)
  local item = ui.select({
    { text = ui.row(I.lock, "Reintroducir contraseña", false), id = "pw" },
    { text = ui.row(I.trash, "Olvidar red", false), id = "forget" },
  }, { prompt = TITLE, mesg = ui.mesg({ n.ssid, "contraseña incorrecta" }) })
  if not item then return end

  if item.id == "forget" then
    forget_network(n, uuids)
    return
  end

  local pw = ask_password(n)
  if not pw then return end
  local mod = nm("connection modify uuid " .. ui.quote(uuids[1]) .. " wifi-sec.psk " .. ui.quote(pw), 10)
  if not mod.ok then
    fail("No se pudo guardar la contraseña: " .. explain(mod))
    return
  end
  ui.notify(TITLE, "Conectando a " .. n.ssid .. "…", { tag = "net" })
  local res = activate_saved(dev, uuids[1])
  if res.ok then
    ui.notify(TITLE, "Conectado a " .. n.ssid, { tag = "net" })
  else
    fail("No se pudo conectar a «" .. n.ssid .. "»: " .. explain(res))
  end
end

local function connect_network(dev, n, saved)
  local uuids = saved[n.ssid]

  -- Red guardada: se activa el perfil existente.
  if uuids then
    ui.notify(TITLE, "Conectando a " .. n.ssid .. "…", { tag = "net" })
    local res = activate_saved(dev, uuids[1])
    if res.ok then
      ui.notify(TITLE, "Conectado a " .. n.ssid, { tag = "net" })
    elseif is_bad_password(res) and n.secured then
      bad_password_menu(dev, n, uuids)
    else
      fail("No se pudo conectar a «" .. n.ssid .. "»: " .. explain(res))
    end
    return
  end

  -- Red nueva.
  if n.enterprise then
    fail("«" .. n.ssid .. "» es una red empresarial (802.1X); configúrala con nmtui o nm-connection-editor")
    return
  end

  local cmd = "-w " .. CONNECT_TIMEOUT .. " device wifi connect " .. ui.quote(n.ssid)
    .. " ifname " .. ui.quote(dev.name)
  if n.secured then
    local pw = ask_password(n)
    if not pw then return end
    cmd = cmd .. " password " .. ui.quote(pw)
  end

  local before = uuid_set(saved)
  ui.notify(TITLE, "Conectando a " .. n.ssid .. "…", { tag = "net" })
  local res = nm(cmd, CONNECT_TIMEOUT + 10)
  if res.ok then
    ui.notify(TITLE, "Conectado a " .. n.ssid, { tag = "net" })
    return
  end

  -- nmcli puede dejar un perfil huérfano con la contraseña mala; si no se
  -- borra, la próxima vez la red parecería "guardada" y fallaría en silencio.
  local orphans = {}
  for _, u in ipairs(saved_profiles()[n.ssid] or {}) do
    if not before[u] then orphans[#orphans + 1] = u end
  end
  if #orphans > 0 then delete_profiles(orphans) end
  fail("No se pudo conectar a «" .. n.ssid .. "»: " .. explain(res))
end

-- Devuelve true si se ejecutó una acción (fin), false si se canceló (volver).
local function network_options(dev, n, saved)
  local uuids = saved[n.ssid]
  local items = {}
  if n.in_use then
    items[#items + 1] = { text = ui.row(I.unlink, "Desconectar", false), id = "down" }
  else
    items[#items + 1] = { text = ui.row(I.link, "Conectar", false), id = "up" }
  end
  if uuids then
    items[#items + 1] = { text = ui.row(I.trash, "Olvidar red…", false), id = "forget" }
  end

  local state = { n.ssid, n.signal .. "%", security_label(n) }
  local item = ui.select(items, { prompt = TITLE, mesg = ui.mesg(state) })
  if not item then return false end

  if item.id == "down" then
    local res = nm("device disconnect " .. ui.quote(dev.name), 15)
    if not res.ok then fail("No se pudo desconectar: " .. explain(res)) end
  elseif item.id == "up" then
    connect_network(dev, n, saved)
  elseif item.id == "forget" then
    if not ui.confirm("¿Olvidar «" .. n.ssid .. "»? Habrá que volver a escribir la contraseña.", "Sí, olvidar") then
      return false
    end
    forget_network(n, uuids)
  end
  return true
end

local function rescan(dev)
  ui.notify(TITLE, "Buscando redes…", { tag = "net" })
  local res = nm("device wifi rescan ifname " .. ui.quote(dev.name), 15)
  if not res.ok then
    -- NetworkManager limita los escaneos seguidos; es un aviso benigno.
    local low = (res.err .. res.out):lower()
    if not low:find("not allowed", 1, true) then fail("No se pudo actualizar: " .. explain(res)) end
  end
  ui.sleep(RESCAN_WAIT)
end

local function set_radio(on)
  local res = nm("radio wifi " .. (on and "on" or "off"), 10)
  if not res.ok then
    fail("No se pudo " .. (on and "encender" or "apagar") .. " el Wi-Fi: " .. explain(res))
    return
  end
  if on then ui.sleep(2) end -- deja que NetworkManager empiece a escanear
end

-- ─── Menú principal ────────────────────────────────────────────────────────

local function main()
  if not ui.require_cmds({ "nmcli" }, TITLE) then return end

  while true do
    local dev, err = find_wifi_device()
    if not dev then
      fail(err)
      return
    end
    if dev.state == "unmanaged" then
      fail("La interfaz " .. dev.name .. " no está gestionada por NetworkManager")
      return
    end

    local items, mesg = {}, nil
    local nets, saved = {}, {}

    if not wifi_enabled() then
      items[1] = { text = ui.row(I.wifi, "Encender Wi-Fi", false), id = "on" }
      mesg = ui.mesg({ I.wifi_off .. " Wi-Fi apagado" })
    else
      local list, lerr = list_networks(dev.name)
      if not list then
        fail(lerr)
        return
      end
      nets = list
      saved = saved_profiles()

      table.sort(nets, function(a, b)
        if a.in_use ~= b.in_use then return a.in_use end
        local sa, sb = saved[a.ssid] ~= nil, saved[b.ssid] ~= nil
        if sa ~= sb then return sa end
        if a.signal ~= b.signal then return a.signal > b.signal end
        return a.ssid < b.ssid
      end)

      local current
      for _, n in ipairs(nets) do
        if n.in_use then current = n end
        -- Candado solo donde realmente pedirá contraseña.
        local lock = ((n.secured or n.enterprise) and not saved[n.ssid]) and I.lock or nil
        items[#items + 1] = { text = ui.row(signal_icon(n.signal), n.ssid, n.in_use, lock), id = "net", net = n }
      end
      items[#items + 1] = { text = ui.row(I.refresh, "Actualizar", false), id = "refresh" }
      items[#items + 1] = { text = ui.row(I.wifi_off, "Apagar Wi-Fi", false), id = "off" }

      local state
      if current then
        state = { signal_icon(current.signal) .. " " .. current.ssid, current.signal .. "%", security_label(current) }
      elseif dev.state:find("^connect") and dev.conn ~= "" then
        state = { I.wifi_none .. " " .. dev.conn }
      else
        state = { I.wifi_none .. " Sin conexión" }
      end
      if #nets == 0 then state[#state + 1] = "sin redes visibles" end
      mesg = ui.mesg(state, (#nets > 0) and "Enter: conectar · Alt+Enter: opciones" or nil)
    end

    local item, _, key = ui.select(items, { prompt = TITLE, mesg = mesg, alt = true })
    if not item then return end

    if item.id == "on" then
      set_radio(true)
    elseif item.id == "off" then
      set_radio(false)
    elseif item.id == "refresh" then
      rescan(dev)
    elseif item.id == "net" then
      local n = item.net
      local wants_options = (key == "alt" and (n.in_use or saved[n.ssid])) or (key ~= "alt" and n.in_use)
      if wants_options then
        if network_options(dev, n, saved) then return end
      else
        connect_network(dev, n, saved)
        return
      end
    end
  end
end

main()
