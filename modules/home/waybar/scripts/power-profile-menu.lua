#!/usr/bin/env lua
-- Selector de perfil de energía vía powerprofilesctl + rofi -dmenu.
-- Valores reales confirmados por el usuario (power-saver/balanced/
-- performance, NO "saver" — el script community que encontró tenía
-- exactamente ese bug).
--
-- SIN CONFIRMAR: que power-profiles-daemon.service esté realmente
-- activo. Apareció en un log de nixos-rebuild switch de hace varias
-- fases (se reinició junto con otros servicios), pero eso no confirma
-- que esté habilitado a propósito ni corriendo ahora. Verificar con
-- `systemctl status power-profiles-daemon` antes de asumir que esto
-- funciona de punta a punta.

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

local profiles = {
  { label = "  Rendimiento", value = "performance" },
  { label = "⚖  Balanceado",  value = "balanced" },
  { label = "󰁹  Ahorro",      value = "power-saver" },
}

local function get_current()
  local output = shell("powerprofilesctl get")
  return output:gsub("%s+$", "")
end

local function main()
  local current = get_current()
  local lines = {}
  for i, p in ipairs(profiles) do
    local marker = (p.value == current) and " [actual]" or ""
    lines[i] = p.label .. marker
  end

  local selection = rofi_select(lines, "Perfil de energía")
  if not selection then return end

  for i, line in ipairs(lines) do
    if line == selection then
      os.execute("powerprofilesctl set " .. profiles[i].value)
      -- RTMIN+8: refresca custom/distro en Waybar sin esperar a un
      -- interval de polling — decisión del usuario de usar signal.
      os.execute("pkill -RTMIN+8 waybar")
      break
    end
  end
end

main()
