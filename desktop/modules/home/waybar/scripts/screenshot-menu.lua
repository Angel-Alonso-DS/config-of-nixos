#!/usr/bin/env lua
-- screenshot-menu.lua — menú de capturas de pantalla en dos niveles:
-- qué capturar (región/pantalla/ventana activa) y qué hacer con eso
-- (copiar/guardar/ambos/anotar). Usa `grimblast` para copiar/guardar
-- (sintaxis real: `grimblast (copy|save|copysave) (area|screen|active)
-- [FILE]`, confirmada contra el repo oficial hyprwm/contrib), y una
-- tubería propia de `grim`+`swappy` para anotar, porque `grimblast edit`
-- abre GIMP por defecto y no swappy.
--
-- Sin notificación al terminar (decisión del usuario: "estorban").
-- grimblast tampoco notifica por su cuenta salvo que se le pase -n, así
-- que no hay que suprimir nada de su parte.

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
local TITLE = "Captura"

-- Carpeta con espacios en el nombre: todo comando la usa a través de
-- ui.quote(), nunca interpolada sin comillas.
local SAVE_DIR = os.getenv("HOME") .. "/Pictures/Capturas de pantalla"

local TARGETS = {
  { id = "area",   label = "Región",           icon = I.crop,       grim_geom = "slurp" },
  { id = "screen", label = "Pantalla completa", icon = I.fullscreen, grim_geom = nil },
  { id = "active", label = "Ventana activa",    icon = I.camera,     grim_geom = "active" },
}

local function filename()
  return "captura_" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".png"
end

local function fail(detail)
  ui.notify(TITLE, detail, { urgent = true })
end

-- Construye el comando `grim` que produce el PNG a stdout para un target
-- dado, para usarlo con swappy. No usa grimblast aquí porque su acción
-- `edit` abre GIMP por defecto, no swappy.
local function grim_to_stdout_cmd(target)
  if target.grim_geom == "slurp" then
    return "grim -g \"$(slurp)\" -"
  elseif target.grim_geom == "active" then
    return "grim -g \"$(hyprctl activewindow -j | jq -r '\"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])\"')\" -"
  else
    return "grim -" -- todos los outputs combinados, igual que grimblast "screen"
  end
end

local function do_grimblast(action, target)
  os.execute("mkdir -p " .. ui.quote(SAVE_DIR))
  local cmd = { "grimblast", action, target.id }
  if action == "save" or action == "copysave" then
    cmd[#cmd + 1] = ui.quote(SAVE_DIR .. "/" .. filename())
  end
  local res = ui.run(table.concat(cmd, " "), { timeout = 60 })
  if not res.ok then
    fail("grimblast falló: " .. ui.errmsg(res))
  end
end

local function do_annotate(target)
  os.execute("mkdir -p " .. ui.quote(SAVE_DIR))
  local cmd = grim_to_stdout_cmd(target) .. " | swappy -f -"
  local res = ui.run(cmd, { timeout = 300 }) -- sin límite de tiempo corto: el usuario puede tardar anotando
  if not res.ok then
    fail("No se pudo anotar: " .. ui.errmsg(res))
  end
end

local ACTIONS = {
  { id = "copy",     label = "Copiar",             icon = I.link },
  { id = "save",     label = "Guardar",            icon = I.disk },
  { id = "copysave", label = "Copiar y guardar",   icon = I.check },
  { id = "annotate", label = "Anotar",             icon = I.edit },
}

local function action_menu(target)
  local items = {}
  for i, a in ipairs(ACTIONS) do
    items[i] = { text = ui.row(a.icon, a.label), action = a }
  end
  local item = ui.select(items, { prompt = TITLE, mesg = ui.mesg({ target.label }) })
  if not item then return end

  if item.action.id == "annotate" then
    do_annotate(target)
  else
    do_grimblast(item.action.id, target)
  end
end

local function main()
  if not ui.require_cmds({ "grimblast", "grim", "slurp", "swappy", "jq" }, TITLE) then return end

  local items = {}
  for i, t in ipairs(TARGETS) do
    items[i] = { text = ui.row(t.icon, t.label), target = t }
  end
  local item = ui.select(items, { prompt = TITLE })
  if not item then return end
  action_menu(item.target)
end

main()
