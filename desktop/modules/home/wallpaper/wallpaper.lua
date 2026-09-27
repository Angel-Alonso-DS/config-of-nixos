#!/usr/bin/env lua
-- wallpaper.lua — lógica de selección/rotación/favoritos de wallpapers.
-- Nix solo materializa este archivo (ver wallpaper.nix); toda la lógica
-- dinámica vive aquí en Lua, según la filosofía Nix=declarativo/Lua=lógica
-- del prompt original.
--
-- `awww` (antes `swww`, renombrado por el proyecto) confirmado como el
-- comando correcto: `awww img`, `awww query -j`, `awww-daemon` son todos
-- reales (ver `man awww`). No hay bug de nombre aquí.

local cjson = require("cjson")
local lfs = require("lfs")

-- menu-common.lua vive en ~/.config/waybar/scripts, no junto a este
-- archivo (~/.config/hypr/scripts) — solo lo usa la acción `pick`, así
-- que se busca ahí explícitamente en vez del patrón de symlink de los
-- menús de waybar.
local ui
do
  local home = os.getenv("HOME") or ""
  package.path = home .. "/.config/waybar/scripts/?.lua;" .. package.path
  local ok, mod = pcall(require, "menu-common")
  if ok then ui = mod end -- si falla, solo `pick` queda deshabilitada (ver cmd_pick)
end

local home = os.getenv("HOME")
local wallpaper_dir = home .. "/Pictures/wallpapers/"
local state_dir = home .. "/.local/state/wallpaper-manager/"
local favorites_file = state_dir .. "favorites.json"

local function ensure_state_dir()
  os.execute("mkdir -p '" .. state_dir .. "'")
end

local function list_images()
  local images = {}
  for file in lfs.dir(wallpaper_dir) do
    -- Corregido: match() es case-sensitive en Lua. Sin lower(), archivos
    -- con extensión en mayúsculas (.JPG, .PNG — comunes en imágenes
    -- descargadas) se ignoraban en silencio y la lista quedaba vacía,
    -- sin ningún error visible porque este script corre desatendido.
    local lower_file = file:lower()
    if lower_file:match("%.jpg$") or lower_file:match("%.jpeg$") or lower_file:match("%.png$") then
      table.insert(images, wallpaper_dir .. file)
    end
  end
  table.sort(images)
  return images
end

local function load_favorites()
  ensure_state_dir()
  local f = io.open(favorites_file, "r")
  if not f then return {} end
  local content = f:read("*a")
  f:close()
  if content == "" then return {} end
  local ok, decoded = pcall(cjson.decode, content)
  if not ok then
    io.stderr:write("favorites.json corrupto, se ignora: " .. tostring(decoded) .. "\n")
    return {}
  end
  return decoded
end

local function save_favorites(favs)
  ensure_state_dir()
  local f = io.open(favorites_file, "w")
  f:write(cjson.encode(favs))
  f:close()
end

local function is_favorite(favs, path)
  for _, p in ipairs(favs) do
    if p == path then return true end
  end
  return false
end

local function set_wallpaper(path)
  local ok = os.execute(string.format(
    "awww img '%s' --transition-type grow --transition-duration 1.2 --transition-fps 60",
    path
  ))
  -- os.execute en Lua 5.4 devuelve (true, "exit", 0) en éxito, o
  -- (nil/false, "exit"/"signal", código) en fallo. Antes se ignoraba
  -- este valor por completo — el script podía imprimir "Wallpaper: ..."
  -- aunque `awww img` hubiera fallado (p. ej. sin awww-daemon corriendo).
  return ok == true
end

local function pick_random(images)
  math.randomseed(os.time())
  return images[math.random(#images)]
end

local function cmd_random()
  local images = list_images()
  if #images == 0 then
    io.stderr:write("No hay wallpapers en " .. wallpaper_dir .. "\n")
    os.exit(1)
  end
  local choice = pick_random(images)
  if set_wallpaper(choice) then
    print("Wallpaper: " .. choice)
  else
    io.stderr:write("`awww img` falló para: " .. choice .. " (¿awww-daemon corriendo?)\n")
    os.exit(1)
  end
end

local function cmd_favorite_random()
  local favs = load_favorites()
  if #favs == 0 then
    io.stderr:write("No hay favoritos guardados, usando random general\n")
    cmd_random()
    return
  end
  local choice = pick_random(favs)
  if set_wallpaper(choice) then
    print("Wallpaper (favorito): " .. choice)
  else
    io.stderr:write("`awww img` falló para: " .. choice .. " (¿awww-daemon corriendo?)\n")
    os.exit(1)
  end
end

-- `awww query -j` devuelve JSON por namespace: { "<namespace>": [ { name,
-- width, height, scale, displaying: { image: "..." } o { color: "..." } },
-- ... ] } (confirmado en `man awww-query`). Con varios monitores se toma
-- el primer output con una imagen (todos deberían coincidir, ya que
-- set_wallpaper() nunca usa -o para fijar por-monitor).
local function get_current_wallpaper()
  local handle = io.popen("awww query -j 2>/dev/null")
  local result = handle:read("*a")
  handle:close()
  if not result or result == "" then return nil end

  local ok, decoded = pcall(cjson.decode, result)
  if not ok then return nil end

  for _, outputs in pairs(decoded) do
    for _, out in ipairs(outputs) do
      if out.displaying and out.displaying.image then
        return out.displaying.image
      end
    end
  end
  return nil
end

local function cmd_toggle_favorite()
  local current = get_current_wallpaper()
  if not current then
    io.stderr:write("No se pudo determinar el wallpaper actual vía `awww query`\n")
    os.exit(1)
  end
  local favs = load_favorites()
  local found_index = nil
  for i, p in ipairs(favs) do
    if p == current then found_index = i end
  end
  if found_index then
    table.remove(favs, found_index)
    print("Quitado de favoritos: " .. current)
  else
    table.insert(favs, current)
    print("Agregado a favoritos: " .. current)
  end
  save_favorites(favs)
end

-- ─── Selector interactivo (rofi) ────────────────────────────────────────────
-- Enter aplica el wallpaper elegido; Alt+Enter alterna favorito sobre esa
-- fila sin cerrar el menú (mismo patrón que el resto de los menús rofi).
-- Usa las imágenes originales como icono: rofi las escala solas. Con
-- carpetas grandes de imágenes muy pesadas, la primera apertura puede
-- sentirse lenta — si eso pasa, la solución sería cachear miniaturas
-- reducidas en state_dir, pero no se implementa todavía por mantenerlo
-- simple hasta confirmar que hace falta.
local function cmd_pick()
  if not ui then
    io.stderr:write("No se pudo cargar menu-common.lua (se buscó en ~/.config/waybar/scripts)\n")
    os.exit(1)
  end

  local selected_path = nil
  while true do
    local images = list_images()
    if #images == 0 then
      ui.notify("Wallpaper", "No hay imágenes en " .. wallpaper_dir, { urgent = true })
      return
    end

    local current = get_current_wallpaper()
    local favs = load_favorites()

    local items, selected_idx = {}, nil
    for i, path in ipairs(images) do
      local name = path:match("([^/]+)$") or path
      local fav = is_favorite(favs, path)
      local is_cur = (path == current)
      items[i] = {
        text = ui.row(fav and ui.icons.star or ui.icons.star_outline, name, is_cur),
        icon_path = path,
        path = path,
        current = is_cur,
      }
      if selected_path and path == selected_path then selected_idx = i end
    end

    local item, idx, key = ui.select(items, {
      prompt = "Wallpaper",
      mesg = ui.mesg({ "Enter: aplicar · Alt+Enter: favorito" }),
      alt = true,
      show_icons = true,
      selected = selected_idx,
    })
    if not item then return end

    if key == "alt" then
      local fav = is_favorite(favs, item.path)
      if fav then
        for i, p in ipairs(favs) do if p == item.path then table.remove(favs, i); break end end
      else
        table.insert(favs, item.path)
      end
      save_favorites(favs)
      selected_path = item.path -- vuelve a abrir en la misma fila
    else
      if set_wallpaper(item.path) then
        print("Wallpaper: " .. item.path)
      else
        ui.notify("Wallpaper", "`awww img` falló (¿awww-daemon corriendo?)", { urgent = true })
      end
      return
    end
  end
end

local action = arg[1]

if action == "random" then
  cmd_random()
elseif action == "favorite-random" then
  cmd_favorite_random()
elseif action == "toggle-favorite" then
  cmd_toggle_favorite()
elseif action == "pick" then
  cmd_pick()
else
  print("Uso: wallpaper.lua [random|favorite-random|toggle-favorite|pick]")
  os.exit(1)
end
