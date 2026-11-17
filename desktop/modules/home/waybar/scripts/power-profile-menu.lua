#!/usr/bin/env lua
-- power-profile-menu.lua — selector de perfil de energía (powerprofilesctl).
-- Los perfiles se leen del sistema (`powerprofilesctl list`); no se asume
-- que existan los tres clásicos. Refresca Waybar solo si el cambio funcionó.

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

-- Señal con la que Waybar refresca el módulo (custom/... "signal": 8).
local WAYBAR_SIGNAL = "RTMIN+8"

local META = {
  ["performance"] = { label = "Rendimiento", icon = I.performance, order = 1 },
  ["balanced"]    = { label = "Balanceado",  icon = I.balanced,    order = 2 },
  ["power-saver"] = { label = "Ahorro",      icon = I.saver,       order = 3 },
}

local function meta_for(name)
  return META[name] or { label = name, icon = I.cog, order = 99 }
end

-- Lee perfiles y cuál está activo. Formato de `powerprofilesctl list`:
--   * balanced:            (el asterisco marca el activo)
--       CpuDriver: ...
--       Degraded:  yes (lap-detected)
local function read_profiles()
  local res = ui.run("powerprofilesctl list", { c_locale = true, timeout = 5 })
  if not res.ok then return nil, res end

  local profiles, cur = {}, nil
  for line in res.out:gmatch("[^\n]+") do
    local star, name = line:match("^([ %*]) ([%w_%-]+):%s*$")
    if name then
      cur = { name = name, active = (star == "*") }
      profiles[#profiles + 1] = cur
    elseif cur then
      local deg = line:match("^%s+Degraded:%s*(.-)%s*$")
      if deg and deg:match("^yes") then
        cur.degraded = deg:match("%((.-)%)") or "sí"
      end
    end
  end

  local have_active = false
  for _, p in ipairs(profiles) do if p.active then have_active = true end end
  if not have_active and #profiles > 0 then
    local g = ui.run("powerprofilesctl get", { timeout = 5 })
    local current = ui.trim(g.out)
    for _, p in ipairs(profiles) do p.active = (p.name == current) end
  end

  table.sort(profiles, function(a, b)
    local oa, ob = meta_for(a.name).order, meta_for(b.name).order
    if oa ~= ob then return oa < ob end
    return a.name < b.name
  end)
  return profiles
end

local function main()
  if not ui.have("powerprofilesctl") then
    ui.notify("Perfil de energía",
      "No se encontró powerprofilesctl (paquete power-profiles-daemon)", { urgent = true })
    return
  end

  local profiles, res = read_profiles()
  if not profiles then
    ui.notify("Perfil de energía",
      "power-profiles-daemon no responde: " .. ui.errmsg(res)
        .. ". Revisa: systemctl status power-profiles-daemon",
      { urgent = true })
    return
  end
  if #profiles == 0 then
    ui.notify("Perfil de energía", "El sistema no reporta ningún perfil disponible", { urgent = true })
    return
  end

  local items, state = {}, {}
  for i, p in ipairs(profiles) do
    local m = meta_for(p.name)
    items[i] = {
      text = ui.row(m.icon, m.label, p.active, p.degraded and "limitado" or nil),
      profile = p,
      current = p.active,
    }
    if p.active then
      state[#state + 1] = m.icon .. " " .. m.label
      if p.degraded then state[#state + 1] = "limitado: " .. p.degraded end
    end
  end

  local item = ui.select(items, {
    prompt = "Perfil de energía",
    mesg = (#state > 0) and ui.mesg(state) or nil,
  })
  if not item then return end
  if item.profile.active then return end -- ya es el actual

  local set = ui.run("powerprofilesctl set " .. ui.quote(item.profile.name), { timeout = 10 })
  if not set.ok then
    ui.notify("Perfil de energía",
      "No se pudo cambiar a " .. meta_for(item.profile.name).label .. ": " .. ui.errmsg(set),
      { urgent = true, tag = "profile" })
    return
  end

  -- Waybar puede no estar corriendo: no es un error, se ignora el resultado.
  ui.run("pkill -" .. WAYBAR_SIGNAL .. " -x waybar", { timeout = 3 })
end

main()
