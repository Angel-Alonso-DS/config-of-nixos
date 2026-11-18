#!/usr/bin/env lua
-- monitor-menu.lua — gestor de monitores en caliente, para conexiones
-- momentáneas (TV, monitor externo). Solo aplica para la sesión actual,
-- igual que xrandr — nada de esto se guarda; un cambio permanente se
-- agrega a mano en hyprland.lua (ver el bloque de la TV ya comentado ahí).
--
-- IMPORTANTE: como hyprland.lua usa el parser Lua nativo (hl.monitor(),
-- hl.bind(), ...), `hyprctl keyword monitor ...` NO FUNCIONA — falla en
-- silencio (exit 0, sin efecto; confirmado como bug conocido de Hyprland
-- con configuración Lua). La forma correcta y confirmada contra la wiki
-- oficial es `hyprctl eval 'hl.monitor({ ... })'`, con los mismos campos
-- que ya usas en hyprland.lua (output/mode/position/scale/disabled) más
-- `mirror = "<nombre>"` para espejo.
--
-- ADVERTENCIA: esta parte de Hyprland (parser Lua + eval en caliente) es
-- muy reciente y hay reportes abiertos de reactivar un monitor deshabilitado
-- sin comportarse del todo bien en algunas versiones. Si "Reactivar" no
-- trae de vuelta el monitor, el único arreglo conocido por ahora es
-- `hyprctl reload` (recarga hyprland.lua) o reiniciar la sesión.

local cjson = require("cjson")

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
local TITLE = "Monitores"

-- ─── Lectura (siempre por `hyprctl monitors all -j`, no por keyword) ──────
-- Esta parte SÍ funciona igual con parser legacy o Lua: es una consulta,
-- no un `keyword`.

local function list_monitors()
  local res = ui.run("hyprctl monitors all -j", { timeout = 8 })
  if not res.ok then return nil, ui.errmsg(res, "hyprctl no respondió") end

  local ok, decoded = pcall(cjson.decode, res.out)
  if not ok or type(decoded) ~= "table" then return nil, "salida de `hyprctl monitors all -j` no reconocida" end

  local monitors = {}
  for _, m in ipairs(decoded) do
    local mirror = m.mirrorOf
    if mirror == cjson.null or mirror == "none" or mirror == "" then mirror = nil end
    monitors[#monitors + 1] = {
      name = m.name,
      description = m.description,
      mode = string.format("%dx%d@%s", math.floor(m.width or 0), math.floor(m.height or 0),
        (string.format("%g", m.refreshRate or 0))),
      x = m.x, y = m.y,
      scale = m.scale,
      disabled = m.disabled == true,
      mirror_of = mirror,
      available_modes = m.availableModes or {},
    }
  end
  return monitors
end

-- ─── Escritura (siempre por `hyprctl eval`) ────────────────────────────────

local function lua_literal(v)
  if type(v) == "string" then return "\"" .. v:gsub("\\", "\\\\"):gsub("\"", "\\\"") .. "\"" end
  if type(v) == "boolean" or type(v) == "number" then return tostring(v) end
  error("tipo no soportado en lua_literal: " .. type(v))
end

-- fields: tabla con las claves de hl.monitor() a aplicar. `output` siempre
-- se agrega automáticamente con el `name` del monitor.
local function apply_monitor(name, fields)
  local parts = { "output = " .. lua_literal(name) }
  for k, v in pairs(fields) do
    parts[#parts + 1] = k .. " = " .. lua_literal(v)
  end
  local expr = "hl.monitor({ " .. table.concat(parts, ", ") .. " })"
  local res = ui.run("hyprctl eval " .. ui.quote(expr), { timeout = 8 })
  local out = ui.trim(res.out)
  -- `hyprctl eval` puede devolver 0 y aun así reportar un error de Lua en
  -- el propio texto de salida (no siempre en stderr) — se revisan ambos.
  if not res.ok or out:lower():find("error") or (res.err ~= "" and ui.trim(res.err) ~= "") then
    return false, ui.errmsg(res, out ~= "" and out or "sin detalle")
  end
  return true
end

-- ─── Acciones ──────────────────────────────────────────────────────────────

local function do_extend(mon, side)
  local ok, err = apply_monitor(mon.name, {
    mode = mon.mode, scale = mon.scale, position = side, disabled = false,
  })
  if not ok then ui.notify(TITLE, "No se pudo extender: " .. err, { urgent = true }) end
end

local function do_mirror(mon, source_name)
  local ok, err = apply_monitor(mon.name, {
    mode = "preferred", position = "auto", scale = 1, mirror = source_name, disabled = false,
  })
  if not ok then ui.notify(TITLE, "No se pudo espejar: " .. err, { urgent = true }) end
end

local function do_disable(mon)
  local ok, err = apply_monitor(mon.name, { disabled = true })
  if not ok then ui.notify(TITLE, "No se pudo desactivar: " .. err, { urgent = true }) end
end

local function do_enable(mon)
  local ok, err = apply_monitor(mon.name, { disabled = false, mode = "preferred", position = "auto" })
  if not ok then
    ui.notify(TITLE, "No se pudo reactivar: " .. err
      .. ". Si el monitor sigue apagado, prueba `hyprctl reload`.", { urgent = true })
  end
end

-- "1920x1080@144.00Hz" (formato de availableModes) -> "1920x1080@144"
-- (formato que usa hl.monitor(), igual al de tu hyprland.lua).
local function clean_mode(raw)
  local base, rate = raw:match("^(%d+x%d+)@([%d%.]+)Hz$")
  if not base then return raw end
  rate = rate:gsub("%.00$", "")
  return base .. "@" .. rate
end

local function do_set_mode(mon, raw_mode)
  local ok, err = apply_monitor(mon.name, {
    mode = clean_mode(raw_mode), position = string.format("%dx%d", mon.x, mon.y),
    scale = mon.scale, disabled = false,
  })
  if not ok then ui.notify(TITLE, "No se pudo cambiar de modo: " .. err, { urgent = true }) end
end

-- ─── Submenús ──────────────────────────────────────────────────────────────

local function mode_menu(mon)
  if #mon.available_modes == 0 then
    ui.notify(TITLE, "El monitor no reporta modos soportados", { urgent = true })
    return
  end
  local items = {}
  for i, m in ipairs(mon.available_modes) do
    items[i] = { text = ui.row(I.display, clean_mode(m), clean_mode(m) == mon.mode), raw = m }
  end
  local item = ui.select(items, { prompt = "Resolución", mesg = ui.mesg({ mon.name }) })
  if item then do_set_mode(mon, item.raw) end
end

local function mirror_source_menu(mon, all_monitors)
  local items = {}
  for _, other in ipairs(all_monitors) do
    if other.name ~= mon.name and not other.disabled then
      items[#items + 1] = { text = ui.row(I.mirror, other.name, nil, other.mode), name = other.name }
    end
  end
  if #items == 0 then
    ui.notify(TITLE, "No hay otro monitor activo para usar como fuente", { urgent = true })
    return
  end
  local item = ui.select(items, { prompt = "Espejar desde", mesg = ui.mesg({ mon.name }) })
  if item then do_mirror(mon, item.name) end
end

local function monitor_actions_menu(mon, all_monitors)
  if mon.disabled then
    local item = ui.select({
      { text = ui.row(I.display, "Reactivar", false) },
    }, { prompt = mon.name, mesg = ui.mesg({ "Desactivado" }) })
    if item then do_enable(mon) end
    return
  end

  local state = { mon.mode, "escala " .. tostring(mon.scale) }
  if mon.mirror_of then state[#state + 1] = "espejo de " .. mon.mirror_of end

  local items = {
    { text = ui.row(I.expand, "Extender a la derecha"), id = "ext_r" },
    { text = ui.row(I.expand, "Extender a la izquierda"), id = "ext_l" },
    { text = ui.row(I.mirror, "Espejo…"), id = "mirror" },
    { text = ui.row(I.display, "Resolución y frecuencia…"), id = "mode" },
    { text = ui.row(I.close, "Desactivar"), id = "off" },
  }
  local item = ui.select(items, { prompt = mon.name, mesg = ui.mesg(state) })
  if not item then return end

  if item.id == "ext_r" then do_extend(mon, "auto-right")
  elseif item.id == "ext_l" then do_extend(mon, "auto-left")
  elseif item.id == "mirror" then mirror_source_menu(mon, all_monitors)
  elseif item.id == "mode" then mode_menu(mon)
  elseif item.id == "off" then do_disable(mon)
  end
end

-- ─── Menú principal ────────────────────────────────────────────────────────

local function main()
  if not ui.require_cmds({ "hyprctl" }, TITLE) then return end

  while true do
    local monitors, err = list_monitors()
    if not monitors then
      ui.notify(TITLE, err, { urgent = true })
      return
    end

    local items = {}
    for i, m in ipairs(monitors) do
      local extra = m.disabled and "desactivado" or (m.mirror_of and ("espejo de " .. m.mirror_of) or m.mode)
      items[i] = { text = ui.row(I.display, m.name, nil, extra), mon = m }
    end

    local item = ui.select(items, { prompt = TITLE })
    if not item then return end
    monitor_actions_menu(item.mon, monitors)
  end
end

main()
