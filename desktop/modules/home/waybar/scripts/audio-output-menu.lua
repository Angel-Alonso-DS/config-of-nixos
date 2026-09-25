#!/usr/bin/env lua
-- audio-output-menu.lua — selector de audio (salida y entrada) vía pactl.
--
-- Uso:  audio-output-menu.lua            → elige Salida/Entrada y luego el dispositivo
--       audio-output-menu.lua sink       → salidas directamente   (también: output, salida)
--       audio-output-menu.lua source     → entradas directamente  (también: input, entrada)
--
-- Enter      : usar como dispositivo por defecto (y mover los streams activos).
-- Alt+Enter  : silenciar / activar sonido de ese dispositivo.
--
-- Las descripciones vienen de `pactl list` con LC_ALL=C, así que las etiquetas
-- ("Description:", "Mute:") no dependen del idioma del sistema.

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

local KINDS = {
  sink = {
    title = "Salida", prompt = "Salida de audio", icon = I.speaker,
    streams = "sink-inputs", move = "move-sink-input", none = "No hay dispositivos de salida",
  },
  source = {
    title = "Entrada", prompt = "Entrada de audio", icon = I.mic,
    streams = "source-outputs", move = "move-source-output", none = "No hay micrófonos disponibles",
  },
}
local KIND_ORDER = { "sink", "source" }

local ALIASES = {
  sink = "sink", output = "sink", salida = "sink", out = "sink",
  source = "source", input = "source", entrada = "source", ["in"] = "source",
}

-- ─── Lectura de dispositivos ───────────────────────────────────────────────

local FIELDS = {
  { "^\tName: (.+)$",                       "name" },
  { "^\tDescription: (.+)$",                "desc" },
  { "^\tMute: (%a+)",                       "mute" },
  { "^\tVolume:.-(%d+)%%",                  "vol" },
  { "^\tActive Port: (.+)$",                "port" },
  { '^\t\tdevice%.form_factor = "(.-)"',    "form" },
}

-- Devuelve lista de { name, desc, mute, vol, port, form } o nil, mensaje.
local function get_devices(kind)
  local res = ui.run("pactl list " .. kind .. "s", { c_locale = true, timeout = 8 })
  if not res.ok then return nil, ui.errmsg(res, "pactl no respondió") end

  local header = (kind == "sink") and "^Sink #%d+" or "^Source #%d+"
  local devices, cur = {}, nil
  for line in res.out:gmatch("[^\n]+") do
    if line:match(header) then
      cur = {}
      devices[#devices + 1] = cur
    elseif cur then
      for _, f in ipairs(FIELDS) do
        local v = line:match(f[1])
        if v then cur[f[2]] = v; break end
      end
    end
  end

  local result = {}
  for _, d in ipairs(devices) do
    -- Los ".monitor" son la captura de lo que suena por cada salida, no
    -- micrófonos reales.
    if d.name and not d.name:match("%.monitor$") then
      result[#result + 1] = {
        name = d.name,
        desc = d.desc or d.name,
        mute = (d.mute == "yes"),
        vol = tonumber(d.vol),
        port = d.port,
        form = d.form,
      }
    end
  end
  return result
end

local function get_default(kind)
  local res = ui.run("pactl get-default-" .. kind, { timeout = 5 })
  local name = ui.trim(res.out)
  if res.ok and name ~= "" then return name end
  -- pactl antiguo sin get-default-*: se lee de `pactl info`.
  local info = ui.run("pactl info", { c_locale = true, timeout = 5 })
  return info.out:match("Default " .. (kind == "sink" and "Sink" or "Source") .. ": (%S+)")
end

local function device_icon(kind, d)
  local hay = ((d.name or "") .. " " .. (d.form or "") .. " " .. (d.port or "")):lower()
  if hay:find("bluez", 1, true) then return I.bluetooth_audio end
  if kind == "sink" then
    if hay:find("hdmi", 1, true) or hay:find("displayport", 1, true) then return I.monitor end
    if hay:find("headphone", 1, true) or hay:find("headset", 1, true) then return I.headphones end
  end
  return KINDS[kind].icon
end

-- ─── Acciones ──────────────────────────────────────────────────────────────

-- Mueve los streams que YA suenan/graban al nuevo dispositivo. Las
-- grabaciones que capturan un ".monitor" (OBS, captura de escritorio) se
-- dejan como están: moverlas al micrófono las rompería.
local function move_streams(kind, target)
  local k = KINDS[kind]
  local monitors = {}
  if kind == "source" then
    local s = ui.run("pactl list short sources", { timeout = 5 })
    for line in s.out:gmatch("[^\n]+") do
      local idx, name = line:match("^(%d+)\t(%S+)")
      if idx and name:match("%.monitor$") then monitors[idx] = true end
    end
  end

  local res = ui.run("pactl list short " .. k.streams, { timeout = 5 })
  local moved, failed = 0, 0
  for line in res.out:gmatch("[^\n]+") do
    local id, dev = line:match("^(%d+)\t(%S+)")
    if id and not monitors[dev] then
      local m = ui.run("pactl " .. k.move .. " " .. id .. " " .. ui.quote(target), { timeout = 5 })
      if m.ok then moved = moved + 1 else failed = failed + 1 end
    end
  end
  return moved, failed
end

local function set_default(kind, dev)
  local res = ui.run("pactl set-default-" .. kind .. " " .. ui.quote(dev.name), { timeout = 5 })
  if not res.ok then
    ui.notify("Audio", "No se pudo usar «" .. dev.desc .. "»: " .. ui.errmsg(res), { urgent = true, tag = "audio" })
    return false
  end
  local _, failed = move_streams(kind, dev.name)
  if failed > 0 then
    ui.notify("Audio", failed .. " stream(s) no se pudieron mover; seguirán en el dispositivo anterior", { tag = "audio" })
  end
  return true
end

local function toggle_mute(kind, dev)
  local res = ui.run("pactl set-" .. kind .. "-mute " .. ui.quote(dev.name) .. " toggle", { timeout = 5 })
  if not res.ok then
    ui.notify("Audio", "No se pudo cambiar el silencio: " .. ui.errmsg(res), { urgent = true, tag = "audio" })
  end
end

-- ─── Menús ─────────────────────────────────────────────────────────────────

local function status_text(dev)
  local bits = {}
  if dev.vol then bits[#bits + 1] = dev.vol .. "%" end
  if dev.mute then bits[#bits + 1] = I.volume_off end
  return table.concat(bits, " ")
end

-- Devuelve true si se eligió un dispositivo (fin), false si se canceló (volver).
local function port_menu(kind)
  local k = KINDS[kind]
  local selected
  while true do
    local devices, err = get_devices(kind)
    if not devices then
      ui.notify("Audio", "No se pudo leer los dispositivos: " .. err, { urgent = true, tag = "audio" })
      return true
    end
    if #devices == 0 then
      ui.notify("Audio", k.none, { tag = "audio" })
      return true
    end

    local current = get_default(kind)
    local items = {}
    for i, d in ipairs(devices) do
      local is_cur = (d.name == current)
      local extra = is_cur and status_text(d) or (d.mute and I.volume_off or nil)
      items[i] = {
        text = ui.row(device_icon(kind, d), d.desc, is_cur, extra),
        dev = d,
        current = is_cur,
      }
    end

    local item, idx, key = ui.select(items, {
      prompt = k.prompt,
      mesg = ui.mesg({ k.title }, "Enter: usar · Alt+Enter: silenciar"),
      alt = true,
      selected = selected,
    })
    if not item then return false end

    if key == "alt" then
      toggle_mute(kind, item.dev)
      selected = idx
    else
      set_default(kind, item.dev)
      return true
    end
  end
end

-- Fila resumen de Salida/Entrada para el menú principal.
local function summary_row(kind)
  local k = KINDS[kind]
  local extra
  local devices = get_devices(kind)
  if devices then
    local current = get_default(kind)
    for _, d in ipairs(devices) do
      if d.name == current then
        extra = d.desc .. "  " .. status_text(d)
        break
      end
    end
  end
  return { text = ui.row(k.icon, k.title, nil, extra), kind = kind }
end

local function main()
  if not ui.require_cmds({ "pactl" }, "Audio") then return end

  local direct = ALIASES[(arg and arg[1] or ""):lower()]
  if direct then
    port_menu(direct)
    return
  end

  while true do
    local items = {}
    for _, kind in ipairs(KIND_ORDER) do items[#items + 1] = summary_row(kind) end
    local item = ui.select(items, { prompt = "Audio" })
    if not item then return end
    if port_menu(item.kind) then return end
  end
end

main()
