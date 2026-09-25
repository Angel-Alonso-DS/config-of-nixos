#!/usr/bin/env lua
-- power-menu.lua — menú de energía/sesión vía rofi.
-- Orden de menos a más destructivo. Cerrar sesión, reiniciar y apagar piden
-- confirmación (con "Cancelar" preseleccionado). Los fallos se notifican.

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

-- Comando de logout de Hyprland. Confirmado en tu sistema: la forma vieja
-- ("hyprctl dispatch exit") está rota en Hyprland 0.55+ con config Lua.
local LOGOUT_CMD = "hyprctl dispatch 'hl.dsp.exit()'"

local ACTIONS = {
  { icon = I.lock,    label = "Bloquear",      cmd = "hyprlock" },
  { icon = I.sleep,   label = "Suspender",     cmd = "systemctl suspend" },
  { icon = I.logout,  label = "Cerrar sesión", cmd = LOGOUT_CMD, hypr = true,
    ask = "¿Cerrar la sesión? Se cerrarán todas las aplicaciones.", yes = "Sí, cerrar sesión" },
  { icon = I.restart, label = "Reiniciar",     cmd = "systemctl reboot",
    ask = "¿Reiniciar el equipo?", yes = "Sí, reiniciar" },
  { icon = I.power,   label = "Apagar",        cmd = "systemctl poweroff",
    ask = "¿Apagar el equipo?", yes = "Sí, apagar" },
}

local function execute(action)
  local res = ui.run(action.cmd)
  local failed = not res.ok
  local detail = ui.errmsg(res)
  if action.hypr then
    -- hyprctl puede salir con 0 y escribir el error en stdout; "ok" o vacío
    -- son éxito (al cerrar sesión la conexión muere y puede no haber salida).
    local out = ui.trim(res.out)
    if out ~= "" and out ~= "ok" then failed, detail = true, out end
  end
  if failed then
    ui.notify(action.label, "Falló: " .. detail, { urgent = true, tag = "power" })
  end
end

local function main()
  local items = {}
  for i, a in ipairs(ACTIONS) do
    items[i] = { text = ui.row(a.icon, a.label), action = a }
  end

  local item = ui.select(items, { prompt = "Energía" })
  if not item then return end

  local a = item.action
  if a.ask and not ui.confirm(a.ask, a.yes) then return end
  execute(a)
end

main()
