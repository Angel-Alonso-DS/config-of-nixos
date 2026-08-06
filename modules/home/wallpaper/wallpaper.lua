#!/usr/bin/env lua
-- wallpaper.lua — lógica de selección/rotación/favoritos de wallpapers.
-- Nix solo materializa este archivo (ver wallpaper.nix); toda la lógica
-- dinámica vive aquí en Lua, según la filosofía Nix=declarativo/Lua=lógica
-- del prompt original.
--
-- ADVERTENCIA NO VERIFICADA: cmd_toggle_favorite() depende de parsear el
-- output de `awww query` para saber cuál es el wallpaper actual. No pude
-- confirmar el formato exacto de ese output contra una instalación real
-- de awww. Verifica esto la primera vez que pruebes `toggle-favorite` —
-- si falla, correr `awww query` a mano y ajustar el patrón de match.

local cjson = require("cjson")
local lfs = require("lfs")

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

local function get_current_wallpaper()
  local handle = io.popen("awww query 2>/dev/null")
  local result = handle:read("*a")
  handle:close()
  -- Patrón sin verificar, ver advertencia arriba.
  local path = result:match("image: (.-)\n") or result:match("image: (.*)$")
  return path
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

local action = arg[1]

if action == "random" then
  cmd_random()
elseif action == "favorite-random" then
  cmd_favorite_random()
elseif action == "toggle-favorite" then
  cmd_toggle_favorite()
else
  print("Uso: wallpaper.lua [random|favorite-random|toggle-favorite]")
  os.exit(1)
end
