#!/usr/bin/env lua
-- Selector de audio (salida y entrada) vía pactl + rofi -dmenu. Portado
-- a Lua desde el script Python de referencia que se compartió (mismo
-- patrón -dmenu que ya usamos en red/bluetooth/energía, no el
-- protocolo de "script mode" de Rofi que usaba el original).
--
-- Mejora real sobre el script de referencia: además de cambiar el
-- sink/source por defecto, mueve los streams YA sonando/grabando al
-- nuevo puerto — el original solo afectaba streams futuros, dejando
-- lo que ya estaba activo en el puerto viejo hasta que se reiniciara.
--
-- Ahora también entrada (micrófono), no solo salida — mismo código
-- generalizado con "kind" ("sink"/"source"), ya que pactl expone
-- comandos simétricos para ambos.

local function shell(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function rofi_select(lines, prompt)
  local input = table.concat(lines, "\n")
  local handle = io.popen("printf '%s' " .. shell_quote(input) .. " | rofi -dmenu -p " .. shell_quote(prompt))
  local selection = handle:read("*l")
  handle:close()
  return selection
end

-- Limpia un nombre técnico (alsa_output.pci-0000_05_00.6.analog-stereo,
-- alsa_input.usb-...) a algo más legible sin depender de "Description:"
-- (que sí está traducido y por eso falló antes). No es tan bonito como
-- la descripción real, pero es confiable en cualquier locale.
local function humanize(name)
  local cleaned = name:gsub("^alsa_output%.", ""):gsub("^bluez_output%.", "")
  cleaned = cleaned:gsub("^alsa_input%.", ""):gsub("^bluez_input%.", "")
  cleaned = cleaned:gsub("[%._]", " ")
  return cleaned
end

-- kind: "sink" (salida) o "source" (entrada). pactl usa comandos
-- simétricos para ambos ("list short sinks/sources", "get/set-default-
-- sink/source"), así que un solo bloque de funciones sirve para los dos.
local function get_ports(kind)
  -- CORREGIDO: "pactl list sinks/sources" con parseo de
  -- "Name:"/"Description:" fallaba porque esas etiquetas están
  -- traducidas en locale español ("Nombre:"/"Descripción:") —
  -- confirmado con la salida real del usuario. "list short" usa
  -- valores técnicos, no etiquetas humanas, así que no depende del
  -- idioma del sistema.
  local output = shell("pactl list short " .. kind .. "s")
  local ports = {}
  for line in output:gmatch("[^\n]+") do
    local name = line:match("^%d+%s+(%S+)")
    -- pactl agrega automáticamente sources ".monitor" por cada sink
    -- (para grabar lo que suena por los parlantes) — no son
    -- micrófonos reales, se excluyen del menú de entrada.
    if name and not name:match("%.monitor$") then
      table.insert(ports, { name = name, desc = humanize(name) })
    end
  end
  return ports
end

local function get_current_port(kind)
  local output = shell("pactl get-default-" .. kind)
  return output:gsub("%s+$", "")
end

-- Mueve los streams que YA están sonando/grabando al nuevo puerto — el
-- script de referencia no hacía esto, solo afectaba streams futuros.
local function move_active_streams(kind, port_name)
  local list_cmd = (kind == "sink") and "sink-inputs" or "source-outputs"
  local move_cmd = (kind == "sink") and "move-sink-input" or "move-source-output"
  local output = shell("pactl list short " .. list_cmd)
  for id in output:gmatch("^(%d+)\t") do
    os.execute("pactl " .. move_cmd .. " " .. id .. " " .. shell_quote(port_name))
  end
end

local function port_menu(kind, prompt)
  local ports = get_ports(kind)
  if #ports == 0 then
    -- Antes fallaba en silencio, sin decir nada — mal diseño mío.
    -- Ahora al menos deja rastro para diagnosticar sin adivinar.
    io.stderr:write("No se detectaron " .. kind .. "s. Salida cruda de `pactl list " .. kind .. "s`:\n")
    io.stderr:write(shell("pactl list " .. kind .. "s"))
    return
  end

  local current = get_current_port(kind)
  local lines = {}
  for i, p in ipairs(ports) do
    local marker = (p.name == current) and " [actual]" or ""
    lines[i] = " " .. p.desc .. marker
  end

  local selection = rofi_select(lines, prompt)
  if not selection then return end

  for i, line in ipairs(lines) do
    if line == selection then
      os.execute("pactl set-default-" .. kind .. " " .. shell_quote(ports[i].name))
      move_active_streams(kind, ports[i].name)
      break
    end
  end
end

local function main()
  local direction_options = { "󰓃 Salida", "󰍬 Entrada" }
  local direction = rofi_select(direction_options, "Audio")
  if not direction then return end

  if direction == direction_options[1] then
    port_menu("sink", "Salida de audio")
  elseif direction == direction_options[2] then
    port_menu("source", "Entrada de audio")
  end
end

main()
