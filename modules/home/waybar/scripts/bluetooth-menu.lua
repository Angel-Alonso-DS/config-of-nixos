#!/usr/bin/env lua
-- bluetooth-menu.lua — menú de Bluetooth vía bluetoothctl (BlueZ).
--
-- Enter      : conectar / desconectar el dispositivo.
-- Alt+Enter  : opciones del dispositivo (conectar, confiar, olvidar).
-- Esc        : en un submenú vuelve al anterior; en el menú principal sale.
--
-- Emparejar es una acción EXPLÍCITA y separada: "Buscar dispositivos…" solo
-- escanea; elegir un dispositivo nuevo ejecuta únicamente `pair`. Conectar y
-- confiar los decides tú después, en el menú del dispositivo. Nada en cadena.
--
-- Límite conocido: `pair` desde aquí funciona con dispositivos "Just Works"
-- (audífonos, parlantes, ratones). Teclados con PIN o confirmación numérica
-- necesitan un agente interactivo (bluetoothctl a mano, blueman, etc.).

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

local SCAN_SECONDS = 8
local CONNECT_TIMEOUT = 20
local PAIR_TIMEOUT = 40
local TITLE = "Bluetooth"

local MAC_PATTERN = "%x%x:%x%x:%x%x:%x%x:%x%x:%x%x"

-- ─── bluetoothctl ──────────────────────────────────────────────────────────

local function bt(args, timeout)
  return ui.run("bluetoothctl " .. args, { c_locale = true, timeout = timeout or 10 })
end

-- bluetoothctl no siempre sale con código != 0 cuando falla: se lee la salida.
local function bt_failed(res)
  if not res.ok or res.timed_out then return true end
  return res.out:find("Failed", 1, true) ~= nil
    or res.out:find("org.bluez.Error", 1, true) ~= nil
    or res.out:find("not available", 1, true) ~= nil
end

local EXPLANATIONS = {
  { "not available",          "dispositivo no disponible (¿apagado o fuera de alcance?)" },
  { "page-timeout",           "el dispositivo no respondió (apagado o fuera de alcance)" },
  { "alreadyexists",          "ya está emparejado" },
  { "already exists",         "ya está emparejado" },
  { "authenticationfailed",   "falló la autenticación; prueba olvidar y volver a emparejar" },
  { "authentication failed",  "falló la autenticación; prueba olvidar y volver a emparejar" },
  { "authenticationcanceled", "emparejamiento cancelado" },
  { "authenticationrejected", "el dispositivo rechazó el emparejamiento" },
  { "authenticationtimeout",  "tiempo agotado esperando confirmación en el dispositivo" },
  { "inprogress",             "hay otra operación en curso; espera unos segundos" },
  { "in progress",            "hay otra operación en curso; espera unos segundos" },
  { "not ready",              "el adaptador no está listo" },
  { "profile-unavailable",    "el dispositivo no ofrece un perfil compatible (¿falta el soporte Bluetooth de PipeWire/WirePlumber?)" },
}

local function explain(res)
  if res.timed_out then return "tiempo de espera agotado" end
  local text = res.out .. "\n" .. res.err
  local low = text:lower()
  for _, e in ipairs(EXPLANATIONS) do
    if low:find(e[1], 1, true) then return e[2] end
  end
  for line in text:gmatch("[^\n]+") do
    if line:find("Failed", 1, true) then return ui.trim(line) end
  end
  return ui.first_line(text) or "error desconocido"
end

local function fail(title, detail)
  ui.notify(title, detail, { urgent = true, tag = "bt" })
end

-- ─── Adaptador ─────────────────────────────────────────────────────────────

local function get_adapter()
  local res = bt("show", 5)
  if res.timed_out then
    return nil, "bluetoothd no responde. Revisa: systemctl status bluetooth"
  end
  if res.out:find("No default controller", 1, true) then
    return nil, "No hay ningún adaptador Bluetooth"
  end
  if not res.out:find("Controller", 1, true) then
    return nil, ui.errmsg(res, "no se pudo leer el adaptador")
  end
  local function flag(name) return res.out:match(name .. ":%s*(%a+)") == "yes" end
  return { powered = flag("Powered"), pairable = flag("Pairable"), discoverable = flag("Discoverable") }
end

local function rfkill_state()
  if not ui.have("rfkill") then return {} end
  local res = ui.run("rfkill list bluetooth", { c_locale = true, timeout = 5 })
  return {
    soft = res.out:find("Soft blocked: yes", 1, true) ~= nil,
    hard = res.out:find("Hard blocked: yes", 1, true) ~= nil,
  }
end

local function power_on()
  local rf = rfkill_state()
  if rf.hard then
    fail(TITLE, "Bloqueado por hardware (interruptor físico o tecla Fn). No se puede desbloquear por software.")
    return false
  end
  if rf.soft then
    -- Pasa tras suspender o con teclas Fn en algunos portátiles.
    local r = ui.run("rfkill unblock bluetooth", { timeout = 5 })
    if not r.ok then
      fail(TITLE, "No se pudo desbloquear el radio: " .. ui.errmsg(r))
      return false
    end
    ui.sleep(1)
  end
  local res = bt("power on", 10)
  local a = get_adapter()
  if a and a.powered then return true end
  fail(TITLE, "No se pudo encender: " .. explain(res))
  return false
end

local function power_off()
  local res = bt("power off", 10)
  local a = get_adapter()
  if a and not a.powered then return true end
  fail(TITLE, "No se pudo apagar: " .. explain(res))
  return false
end

-- ─── Dispositivos ──────────────────────────────────────────────────────────

local function parse_devices(out)
  local list = {}
  for line in out:gmatch("[^\n]+") do
    local mac, name = line:match("^Device (" .. MAC_PATTERN .. ") (.*)$")
    if mac then list[#list + 1] = { mac = mac, name = name } end
  end
  return list
end

-- BlueZ >= 5.65 acepta `devices Paired`. Con versiones anteriores se lista
-- todo y se filtra por "Paired: yes" al leer `info`.
local supports_paired_filter
local function bluez_supports_filter()
  if supports_paired_filter == nil then
    local res = ui.run("bluetoothctl --version", { timeout = 5 })
    local maj, min = res.out:match("(%d+)%.(%d+)")
    if maj then
      maj, min = tonumber(maj), tonumber(min)
      supports_paired_filter = (maj > 5) or (maj == 5 and min >= 65)
    else
      supports_paired_filter = true
    end
  end
  return supports_paired_filter
end

-- Un solo shell para todos los `info` (una sola espera con un solo timeout).
-- Los MAC se validaron con MAC_PATTERN, por eso pueden ir sin comillas.
local function load_info(macs)
  local map = {}
  if #macs == 0 then return map end
  local cmds = {}
  for _, m in ipairs(macs) do
    cmds[#cmds + 1] = string.format("echo '@@%s'; bluetoothctl info %s", m, m)
  end
  local res = ui.run(table.concat(cmds, "; "), { c_locale = true, timeout = 15 })

  local cur
  for line in res.out:gmatch("[^\n]+") do
    local mac = line:match("^@@(%S+)")
    if mac then
      cur = {}
      map[mac] = cur
    elseif cur then
      local k, v = line:match("^%s*([%w ]+):%s*(.-)%s*$")
      if k == "Alias" then cur.alias = v
      elseif k == "Name" then cur.name = v
      elseif k == "Paired" then cur.paired = (v == "yes")
      elseif k == "Trusted" then cur.trusted = (v == "yes")
      elseif k == "Connected" then cur.connected = (v == "yes")
      elseif k == "Icon" then cur.icon = v
      elseif k == "Battery Percentage" then cur.battery = tonumber(v:match("%((%d+)%)"))
      end
    end
  end
  return map
end

local function make_device(mac, fallback_name, info)
  info = info or {}
  return {
    mac = mac,
    name = info.alias or info.name or fallback_name or mac,
    connected = info.connected == true,
    trusted = info.trusted == true,
    paired = info.paired == true,
    icon = info.icon,
    battery = info.battery,
  }
end

-- Solo dispositivos EMPAREJADOS, conectados primero.
local function get_paired()
  local res = bt(bluez_supports_filter() and "devices Paired" or "devices", 8)
  local list = parse_devices(res.out)
  local macs = {}
  for i, d in ipairs(list) do macs[i] = d.mac end
  local info = load_info(macs)

  local devices = {}
  for _, d in ipairs(list) do
    local dev = make_device(d.mac, d.name, info[d.mac])
    if dev.paired then devices[#devices + 1] = dev end
  end
  table.sort(devices, function(a, b)
    if a.connected ~= b.connected then return a.connected end
    return a.name:lower() < b.name:lower()
  end)
  return devices
end

local function refresh_device(dev)
  local info = load_info({ dev.mac })
  return make_device(dev.mac, dev.name, info[dev.mac])
end

local TYPE_ICONS = {
  ["audio-headset"] = I.headphones, ["audio-headphones"] = I.headphones,
  ["audio-card"] = I.speaker, ["input-keyboard"] = I.keyboard,
  ["input-mouse"] = I.mouse, ["phone"] = I.phone,
}

local function device_icon(d)
  return TYPE_ICONS[d.icon or ""] or I.bluetooth
end

-- ─── Acciones sobre un dispositivo ─────────────────────────────────────────

local function connect(dev)
  ui.notify(TITLE, "Conectando a " .. dev.name .. "…", { tag = "bt" })
  local res = bt("connect " .. dev.mac, CONNECT_TIMEOUT)
  if res.out:find("Connection successful", 1, true) then
    ui.notify(TITLE, "Conectado: " .. dev.name, { tag = "bt" })
  else
    fail("No se pudo conectar", dev.name .. ": " .. explain(res))
  end
end

local function disconnect(dev)
  local res = bt("disconnect " .. dev.mac, 10)
  if not refresh_device(dev).connected then return end
  fail("No se pudo desconectar", dev.name .. ": " .. explain(res))
end

local function set_trust(dev, trust)
  local res = bt((trust and "trust " or "untrust ") .. dev.mac, 8)
  if res.out:find("succeeded", 1, true) then return end
  fail("No se pudo cambiar la confianza", dev.name .. ": " .. explain(res))
end

local function forget(dev)
  local res = bt("remove " .. dev.mac, 10)
  if bt_failed(res) then
    fail("No se pudo olvidar", dev.name .. ": " .. explain(res))
  else
    ui.notify(TITLE, "Olvidado: " .. dev.name, { tag = "bt" })
  end
end

-- Devuelve true si se ejecutó una acción (el menú termina), false si se
-- canceló (vuelve al menú principal).
local function device_menu(dev)
  local state = { dev.name, dev.mac, dev.connected and "conectado" or "desconectado" }
  if dev.trusted then state[#state + 1] = "confiable" end

  local item = ui.select({
    { text = ui.row(dev.connected and I.unlink or I.link, dev.connected and "Desconectar" or "Conectar"), id = "toggle" },
    { text = ui.row(I.shield, dev.trusted and "Quitar confianza" or "Confiar"), id = "trust" },
    { text = ui.row(I.trash, "Olvidar…"), id = "forget" },
  }, { prompt = TITLE, mesg = ui.mesg(state) })
  if not item then return false end

  if item.id == "toggle" then
    if dev.connected then disconnect(dev) else connect(dev) end
  elseif item.id == "trust" then
    set_trust(dev, not dev.trusted)
  elseif item.id == "forget" then
    if not ui.confirm("¿Olvidar «" .. dev.name .. "»? Habrá que volver a emparejarlo.", "Sí, olvidar") then
      return false
    end
    forget(dev)
  end
  return true
end

-- ─── Búsqueda y emparejamiento ─────────────────────────────────────────────

local function looks_unnamed(d)
  return (d.name:upper():gsub("-", ":")) == d.mac:upper()
end

-- Devuelve la lista de dispositivos NUEVOS (no emparejados) y cuántos sin
-- nombre se ocultaron (suelen ser anuncios BLE anónimos).
local function scan_new()
  ui.notify(TITLE, "Buscando dispositivos (" .. SCAN_SECONDS .. " s)…", { tag = "bt" })
  local scan = bt("--timeout " .. SCAN_SECONDS .. " scan on", SCAN_SECONDS + 6)
  if scan.out:find("Failed", 1, true) then
    fail(TITLE, "No se pudo buscar: " .. explain(scan))
    return nil
  end

  local paired = {}
  for _, d in ipairs(get_paired()) do paired[d.mac] = true end

  local all = parse_devices(bt("devices", 8).out)
  local new, hidden = {}, 0
  for _, d in ipairs(all) do
    if not paired[d.mac] then
      if looks_unnamed(d) then hidden = hidden + 1 else new[#new + 1] = d end
    end
  end
  table.sort(new, function(a, b) return a.name:lower() < b.name:lower() end)
  return new, hidden
end

-- Devuelve true si el flujo terminó con una acción (fin), false para volver.
local function search_flow()
  while true do
    local new, hidden = scan_new()
    if not new then return false end

    local items = {}
    for i, d in ipairs(new) do
      items[i] = { text = ui.row(I.bluetooth, d.name, nil, d.mac), dev = d }
    end
    items[#items + 1] = { text = ui.row(I.refresh, "Buscar de nuevo"), id = "again" }

    local state = { (#new == 0) and "Sin dispositivos nuevos" or (#new .. " nuevo(s)") }
    if hidden > 0 then state[#state + 1] = hidden .. " sin nombre oculto(s)" end
    local hint = (#new > 0) and "Enter: emparejar" or "Pon el dispositivo en modo de emparejamiento"

    local item = ui.select(items, { prompt = "Emparejar", mesg = ui.mesg(state, hint) })
    if not item then return false end

    if item.id ~= "again" then
      local dev = item.dev
      ui.notify(TITLE, "Emparejando con " .. dev.name .. "… (confirma en el dispositivo si lo pide)", { tag = "bt" })
      local res = bt("pair " .. dev.mac, PAIR_TIMEOUT)
      if not res.out:find("Pairing successful", 1, true) then
        fail("No se pudo emparejar", dev.name .. ": " .. explain(res))
        return true
      end
      ui.notify(TITLE, "Emparejado: " .. dev.name, { tag = "bt" })
      -- Solo emparejado. Conectar/confiar lo decides tú en este menú.
      device_menu(refresh_device(dev))
      return true
    end
  end
end

-- ─── Ajustes ───────────────────────────────────────────────────────────────

local function settings_menu()
  while true do
    local a = get_adapter()
    if not a then return end
    local item = ui.select({
      { text = ui.row(I.bluetooth_connect, "Emparejable", a.pairable), id = "pairable" },
      { text = ui.row(I.eye, "Visible para otros dispositivos", a.discoverable), id = "discoverable" },
    }, { prompt = "Ajustes", mesg = ui.mesg({ TITLE, "Ajustes" }) })
    if not item then return end

    local cmd = item.id .. " " .. ((a[item.id]) and "off" or "on")
    local res = bt(cmd, 8)
    if bt_failed(res) then fail(TITLE, "No se pudo cambiar el ajuste: " .. explain(res)) end
  end
end

-- ─── Menú principal ────────────────────────────────────────────────────────

local function main()
  if not ui.require_cmds({ "bluetoothctl" }, TITLE) then return end

  while true do
    local adapter, err = get_adapter()
    if not adapter then
      fail(TITLE, err)
      return
    end

    local items, mesg = {}, nil
    if not adapter.powered then
      items[1] = { text = ui.row(I.bluetooth, "Encender Bluetooth", false), id = "on" }
      mesg = ui.mesg({ I.bluetooth_off .. " Apagado" })
    else
      local devices = get_paired()
      local connected = 0
      for _, d in ipairs(devices) do
        if d.connected then connected = connected + 1 end
        local extra = (d.connected and d.battery) and (I.battery .. " " .. d.battery .. "%") or nil
        items[#items + 1] = { text = ui.row(device_icon(d), d.name, d.connected, extra), id = "device", dev = d }
      end
      items[#items + 1] = { text = ui.row(I.search, "Buscar dispositivos…", false), id = "search" }
      items[#items + 1] = { text = ui.row(I.cog, "Ajustes", false), id = "settings" }
      items[#items + 1] = { text = ui.row(I.bluetooth_off, "Apagar Bluetooth", false), id = "off" }

      local state = { I.bluetooth .. " Encendido" }
      if #devices == 0 then
        state[#state + 1] = "sin dispositivos emparejados"
      else
        state[#state + 1] = connected .. " conectado(s)"
      end
      mesg = ui.mesg(state, (#devices > 0) and "Enter: conectar · Alt+Enter: opciones" or nil)
    end

    local item, _, key = ui.select(items, { prompt = TITLE, mesg = mesg, alt = true })
    if not item then return end

    if item.id == "on" then
      power_on()
    elseif item.id == "off" then
      power_off()
    elseif item.id == "settings" then
      settings_menu()
    elseif item.id == "search" then
      if search_flow() then return end
    elseif item.id == "device" then
      local d = item.dev
      if key == "alt" then
        if device_menu(d) then return end
      else
        if d.connected then disconnect(d) else connect(d) end
        return
      end
    end
  end
end

main()
