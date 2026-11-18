#!/usr/bin/env lua
-- system-info-menu.lua — panel de información del sistema: generación NixOS
-- activa (solo lectura), micrófono, perfil de energía. Solo se invoca por
-- atajo de teclado (no desde Waybar), así que los errores van por
-- notificación normal, sin preocuparse por un click en la barra.
--
-- Deliberadamente SIN cambio de generación (rollback) ni compartir pantalla:
-- ambos se descartaron por decisión del usuario (rollback por su
-- complejidad/riesgo, compartir pantalla porque el televisor de destino
-- resultó incompatible).

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
local TITLE = "Sistema"

-- Directorio de este script, para invocar power-profile-menu.lua junto a él
-- sin depender de una ruta fija en $HOME.
local SCRIPT_DIR
do
  local self = (arg and arg[0]) or ""
  local h = io.popen("readlink -f '" .. self:gsub("'", "'\\''") .. "' 2>/dev/null")
  local real = h and h:read("l") or self
  if h then h:close() end
  SCRIPT_DIR = real:match("^(.*)/") or "."
end

-- ─── Generación de NixOS ───────────────────────────────────────────────────
-- Formato de `nixos-rebuild list-generations` (columnas: número, fecha,
-- hora, versión de kernel, marca "(current)" en la activa). SIN VERIFICAR
-- contra tu salida real más allá de la detección de "(current)"; si el
-- formato de columnas cambia entre versiones, esto sigue funcionando porque
-- no se parsean columnas, solo se muestra la línea tal cual.

local function get_generations()
  local res = ui.run("nixos-rebuild list-generations", { c_locale = true, timeout = 15 })
  if not res.ok then return nil, ui.errmsg(res, "no se pudo listar generaciones") end

  local gens = {}
  for line in res.out:gmatch("[^\n]+") do
    local t = ui.trim(line)
    if t ~= "" then
      gens[#gens + 1] = { text = t, current = t:find("(current)", 1, true) ~= nil }
    end
  end
  return gens
end

local function current_generation_label(gens)
  for _, g in ipairs(gens) do
    if g.current then return (g.text:gsub("%s*%(current%)%s*$", "")) end
  end
  return gens[#gens] and gens[#gens].text or "desconocida"
end

-- Vista de solo lectura: no hay ninguna acción sobre las filas, cualquier
-- selección (o Esc) simplemente vuelve al menú principal.
local function generations_view()
  local gens, err = get_generations()
  if not gens then
    ui.notify(TITLE, err, { urgent = true })
    return
  end
  local items = {}
  for i, g in ipairs(gens) do
    items[i] = { text = ui.row(I.cog, (g.text:gsub("%s*%(current%)%s*$", "")), g.current) }
  end
  ui.select(items, { prompt = "Generaciones", mesg = ui.mesg({ "Solo información" }) })
end

-- ─── Espacio en /nix/store ─────────────────────────────────────────────────
-- `du -sh` recorre todo el árbol; en un store grande puede tardar varios
-- segundos (más si es la primera lectura y el directorio no está en caché
-- de páginas). Por eso el timeout es más generoso que el del resto del menú.
-- Puramente informativo, sin ninguna acción de limpieza desde aquí.

local function nix_store_usage()
  local res = ui.run("du -sh /nix/store", { timeout = 30 })
  if not res.ok then return nil end
  local size = res.out:match("^(%S+)")
  return size
end

-- ─── Micrófono ─────────────────────────────────────────────────────────────

local function get_default_source()
  local res = ui.run("pactl get-default-source", { timeout = 5 })
  local name = ui.trim(res.out)
  if res.ok and name ~= "" then return name end
  return nil
end

-- Devuelve true/false, o nil si no se pudo determinar (sin fuente por
-- defecto, o pactl no responde).
local function mic_muted()
  local source = get_default_source()
  if not source then return nil end
  local res = ui.run("pactl list sources", { c_locale = true, timeout = 8 })
  if not res.ok then return nil end

  local in_block = false
  for line in res.out:gmatch("[^\n]+") do
    if line:match("^Source #%d+") then
      in_block = false
    elseif line:match("^\tName: " .. source:gsub("%p", "%%%1") .. "$") then
      in_block = true
    elseif in_block then
      local mute = line:match("^\tMute: (%a+)")
      if mute then return mute == "yes" end
    end
  end
  return nil
end

local function mic_toggle()
  local source = get_default_source()
  if not source then
    ui.notify(TITLE, "No hay un micrófono por defecto configurado", { urgent = true, tag = "sysinfo" })
    return
  end
  local res = ui.run("pactl set-source-mute " .. ui.quote(source) .. " toggle", { timeout = 5 })
  if not res.ok then
    ui.notify(TITLE, "No se pudo cambiar el micrófono: " .. ui.errmsg(res), { urgent = true, tag = "sysinfo" })
  end
end

-- ─── Perfil de energía ─────────────────────────────────────────────────────

local PROFILE_ICON = {
  ["performance"] = I.performance, ["balanced"] = I.balanced, ["power-saver"] = I.saver,
}
local PROFILE_LABEL = {
  ["performance"] = "Rendimiento", ["balanced"] = "Balanceado", ["power-saver"] = "Ahorro",
}

local function power_profile()
  if not ui.have("powerprofilesctl") then return nil end
  local res = ui.run("powerprofilesctl get", { timeout = 5 })
  if not res.ok then return nil end
  local name = ui.trim(res.out)
  return (name ~= "") and name or nil
end

local function open_power_profile_menu()
  os.execute("lua " .. ui.quote(SCRIPT_DIR .. "/power-profile-menu.lua"))
end

-- ─── Menú principal ────────────────────────────────────────────────────────

local function main()
  while true do
    local items = {}

    local gens = get_generations()
    local gen_extra = gens and current_generation_label(gens) or "no disponible"
    items[#items + 1] = { text = ui.row(I.cog, "Generación NixOS", nil, gen_extra), id = "gen", enabled = gens ~= nil }

    local store_size = nix_store_usage()
    items[#items + 1] = { text = ui.row(I.disk, "/nix/store", nil, store_size or "no disponible"), id = "store", enabled = false }

    local muted = mic_muted()
    local mic_extra = (muted == nil) and "no disponible" or (muted and (I.volume_off .. " muteado") or "activo")
    items[#items + 1] = { text = ui.row(I.mic, "Micrófono", nil, mic_extra), id = "mic", enabled = muted ~= nil }

    local profile = power_profile()
    local profile_extra = profile and (PROFILE_LABEL[profile] or profile) or "no disponible"
    local profile_icon = profile and (PROFILE_ICON[profile] or I.cog) or I.cog
    items[#items + 1] = { text = ui.row(profile_icon, "Perfil de energía", nil, profile_extra), id = "profile" }

    local item = ui.select(items, { prompt = TITLE })
    if not item then return end

    if item.id == "gen" and item.enabled then
      generations_view()
    elseif item.id == "mic" and item.enabled then
      mic_toggle()
    elseif item.id == "profile" then
      open_power_profile_menu()
      return -- ese script abre su propio rofi; no solaparlos
    end
    -- Selección deshabilitada (dato "no disponible"): vuelve a iterar sin hacer nada.
  end
end

main()
