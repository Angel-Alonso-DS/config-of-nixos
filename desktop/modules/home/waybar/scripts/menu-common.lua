-- menu-common.lua
-- Utilidades compartidas por los menús rofi (audio, bluetooth, red, energía,
-- perfiles de energía). Solo lo imprescindible: ejecutar comandos, quoting,
-- rofi, notificaciones, confirmaciones y formato de filas. La lógica de cada
-- menú vive en su propio script.
--
-- Requiere Lua >= 5.3 (utf8.char). Probado con la semántica de Lua 5.4.

local M = {}

-- ─── Iconos ────────────────────────────────────────────────────────────────
-- Una sola familia: Nerd Font, set Material Design (nf-md-*), que JetBrains
-- Mono Nerd Font incluye. Si alguno no se ve bien, se cambia aquí y se
-- corrige en todos los menús a la vez.
local function g(codepoint) return utf8.char(codepoint) end

M.icons = {
  -- Wi-Fi
  wifi = g(0xF05A9), wifi_off = g(0xF05AA), wifi_none = g(0xF092F),
  wifi_1 = g(0xF091F), wifi_2 = g(0xF0922), wifi_3 = g(0xF0925), wifi_4 = g(0xF0928),
  lock = g(0xF033E),
  -- Bluetooth
  bluetooth = g(0xF00AF), bluetooth_off = g(0xF00B2),
  bluetooth_audio = g(0xF00B0), bluetooth_connect = g(0xF00B1),
  keyboard = g(0xF030C), mouse = g(0xF037D), phone = g(0xF011C),
  battery = g(0xF0079), shield = g(0xF0565), eye = g(0xF0208),
  -- Audio
  speaker = g(0xF04C3), headphones = g(0xF02CB), monitor = g(0xF0379),
  mic = g(0xF036C), volume_off = g(0xF0581),
  -- Energía y perfiles
  power = g(0xF0425), sleep = g(0xF04B2), logout = g(0xF0343), restart = g(0xF0709),
  performance = g(0xF04C5), balanced = g(0xF05D1), saver = g(0xF032A),
  -- Acciones genéricas
  link = g(0xF0337), unlink = g(0xF0338), search = g(0xF0349),
  refresh = g(0xF0450), trash = g(0xF01B4), cog = g(0xF0493),
  check = g(0xF012C), close = g(0xF0156), alert = g(0xF0026),
}
local I = M.icons

-- ─── Texto ─────────────────────────────────────────────────────────────────

function M.quote(s)
  local q = tostring(s):gsub("'", "'\\''")
  return "'" .. q .. "'"
end

function M.trim(s)
  return (tostring(s or ""):match("^%s*(.-)%s*$"))
end

-- Escapa markup Pango: -mesg de rofi y los cuerpos de notificación lo
-- interpretan, y un SSID o nombre de dispositivo puede contener & < >.
function M.esc(s)
  local r = tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return r
end

function M.dim(s)
  return '<span alpha="60%">' .. M.esc(s) .. "</span>"
end

function M.first_line(text)
  for line in tostring(text or ""):gmatch("[^\n]+") do
    local t = M.trim(line)
    if t ~= "" then return t end
  end
  return nil
end

local function strip_control(s)
  s = s:gsub("\27%[[%d;?]*%a", "")   -- secuencias ANSI (bluetoothctl las emite)
  s = s:gsub("[\1\2\r]", "")         -- marcadores de readline
  return s
end

-- ─── Ejecución de comandos ─────────────────────────────────────────────────
-- opts.timeout  : segundos; el comando se mata con `timeout` (exit 124).
-- opts.c_locale : fuerza LC_ALL=C para que la salida no dependa del idioma.
-- Devuelve { ok, code, out, err, timed_out }. stdin siempre es /dev/null,
-- así ningún comando se queda esperando entrada interactiva.
function M.run(cmd, opts)
  opts = opts or {}
  local errfile = os.tmpname()
  local parts = {}
  if opts.c_locale then parts[#parts + 1] = "LC_ALL=C" end
  if opts.timeout then parts[#parts + 1] = "timeout " .. math.floor(opts.timeout) end
  parts[#parts + 1] = "sh -c " .. M.quote(cmd)
  local full = table.concat(parts, " ") .. " </dev/null 2>" .. M.quote(errfile)

  local h = io.popen(full, "r")
  if not h then
    os.remove(errfile)
    return { ok = false, code = -1, out = "", err = "no se pudo ejecutar el comando", timed_out = false }
  end
  local out = h:read("a") or ""
  local ok, _, code = h:close()
  code = code or 0

  local ef = io.open(errfile, "r")
  local err = ""
  if ef then err = ef:read("a") or ""; ef:close() end
  os.remove(errfile)

  return {
    ok = (ok == true),
    code = code,
    out = strip_control(out),
    err = strip_control(err),
    timed_out = (code == 124),
  }
end

-- Primera línea útil del error de un comando ("Error: " sin prefijo).
function M.errmsg(res, fallback)
  if res.timed_out then return "tiempo de espera agotado" end
  local line = M.first_line(res.err) or M.first_line(res.out)
  if not line then return fallback or ("código de salida " .. tostring(res.code)) end
  local cleaned = line:gsub("^[Ee]rror:%s*", "")
  return cleaned
end

function M.have(cmd)
  return M.run("command -v " .. M.quote(cmd), { timeout = 3 }).ok
end

function M.sleep(seconds)
  os.execute("sleep " .. tostring(seconds))
end

-- ─── Notificaciones ────────────────────────────────────────────────────────
-- opts.urgent : urgencia crítica (errores).
-- opts.tag    : las notificaciones con el mismo tag se reemplazan entre sí
--               (si el daemon lo soporta), p. ej. "Conectando…" → "Conectado".
function M.notify(title, body, opts)
  opts = opts or {}
  local cmd = { "notify-send", "-a", "menus" }
  if opts.urgent then cmd[#cmd + 1] = "-u critical" end
  if opts.tag then
    cmd[#cmd + 1] = "-h " .. M.quote("string:x-canonical-private-synchronous:" .. opts.tag)
  end
  cmd[#cmd + 1] = M.quote(title)
  if body and body ~= "" then cmd[#cmd + 1] = M.quote(M.esc(body)) end
  local res = M.run(table.concat(cmd, " "), { timeout = 5 })
  if not res.ok then
    io.stderr:write(title .. (body and (": " .. body) or "") .. "\n")
  end
end

function M.require_cmds(cmds, title)
  for _, c in ipairs(cmds) do
    if not M.have(c) then
      M.notify(title, "No se encontró '" .. c .. "' en el PATH", { urgent = true })
      return false
    end
  end
  return true
end

-- ─── Formato de filas ──────────────────────────────────────────────────────
-- mark: nil → sin columna de marca; true → "●"; false → columna en blanco.
-- Todas las listas con estado usan la misma anatomía: [marca] icono nombre extra
function M.row(icon, text, mark, extra)
  local s = ""
  if mark ~= nil then s = (mark and "●" or " ") .. " " end
  s = s .. icon .. "  " .. text
  if extra and extra ~= "" then s = s .. "  " .. extra end
  return s
end

-- Encabezado de una línea (-mesg): partes de estado separadas por " · " y,
-- opcionalmente, una pista atenuada al final.
function M.mesg(parts, hint)
  local esc = {}
  for _, p in ipairs(parts) do esc[#esc + 1] = M.esc(p) end
  local s = table.concat(esc, " · ")
  if hint then s = s .. "   " .. M.dim(hint) end
  return s
end

-- ─── Rofi ──────────────────────────────────────────────────────────────────

-- Ejecuta rofi -dmenu leyendo `lines` desde un archivo temporal (sin límite
-- de longitud de argv). Devuelve stdout (1ª línea), código de salida y stderr.
local function rofi_call(lines, args)
  local infile, errfile = os.tmpname(), os.tmpname()
  local f = io.open(infile, "w")
  if f then
    if #lines > 0 then f:write(table.concat(lines, "\n"), "\n") end
    f:close()
  end
  local h = io.popen("rofi -dmenu " .. args .. " <" .. M.quote(infile) .. " 2>" .. M.quote(errfile), "r")
  local out, code = nil, -1
  if h then
    out = h:read("l")
    local _, _, c = h:close()
    code = c or 0
  end
  local ef = io.open(errfile, "r")
  local err = ""
  if ef then err = ef:read("a") or ""; ef:close() end
  os.remove(infile)
  os.remove(errfile)
  return out, code, err
end

-- 0 = selección, 1 = cancelado (Esc), 10..28 = tecla personalizada.
-- Cualquier otro código es un fallo real de rofi y se notifica.
local function rofi_failed(code, err)
  if code == 0 or code == 1 or (code >= 10 and code <= 28) then return false end
  local detail = M.first_line(err) or ("rofi terminó con código " .. tostring(code))
  M.notify("Rofi", detail, { urgent = true })
  return true
end

-- items: lista de strings o de tablas { text = "...", current = bool, ... }.
-- opts : prompt, mesg, selected (índice 1-based), alt (habilita Alt+Enter),
--        no_custom (por defecto true: solo se puede elegir de la lista).
-- Devuelve: item, índice, tecla ("enter" | "alt"); o nil si se canceló.
-- Selecciona por ÍNDICE (-format i), no por texto: sin ambigüedad con
-- nombres repetidos ni con iconos.
function M.select(items, opts)
  opts = opts or {}
  local lines, selected = {}, opts.selected
  for i, it in ipairs(items) do
    local text = (type(it) == "table") and it.text or tostring(it)
    lines[i] = (text:gsub("\n", " "))
    if not selected and type(it) == "table" and it.current then selected = i end
  end

  local args = { "-i", "-format i", "-p " .. M.quote(opts.prompt or "") }
  if opts.no_custom ~= false then args[#args + 1] = "-no-custom" end
  if opts.mesg then args[#args + 1] = "-mesg " .. M.quote(opts.mesg) end
  if selected then args[#args + 1] = "-selected-row " .. (selected - 1) end
  if opts.alt then args[#args + 1] = "-kb-custom-1 " .. M.quote("Alt+Return") end

  local out, code, err = rofi_call(lines, table.concat(args, " "))
  if rofi_failed(code, err) then return nil end
  if code ~= 0 and code ~= 10 then return nil end

  local idx = tonumber(out or "")
  if not idx then return nil end
  idx = idx + 1
  local item = items[idx]
  if item == nil then return nil end
  return item, idx, (code == 10) and "alt" or "enter"
end

-- Campo de texto libre. opts: password (oculta lo escrito), mesg.
-- Devuelve el texto o nil si se canceló.
function M.input(prompt, opts)
  opts = opts or {}
  local args = { "-p " .. M.quote(prompt) }
  if opts.password then args[#args + 1] = "-password" end
  if opts.mesg then args[#args + 1] = "-mesg " .. M.quote(opts.mesg) end
  local out, code, err = rofi_call({}, table.concat(args, " "))
  if rofi_failed(code, err) then return nil end
  if code ~= 0 then return nil end
  return out
end

-- Confirmación de acciones destructivas. "Cancelar" va PRIMERO y es la fila
-- preseleccionada: Enter, Enter nunca ejecuta la acción.
function M.confirm(question, yes_label)
  local item = M.select({
    { text = M.row(I.close, "Cancelar"), id = "no" },
    { text = M.row(I.check, yes_label), id = "yes" },
  }, { prompt = "Confirmar", mesg = M.esc(question) })
  return item ~= nil and item.id == "yes"
end

return M
