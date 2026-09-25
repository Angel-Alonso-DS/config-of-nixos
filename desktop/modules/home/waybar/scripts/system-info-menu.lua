#!/usr/bin/env lua
-- Visor de información del sistema — generación NixOS, micrófono,
-- compartir pantalla, perfil de energía. Mismo patrón rofi -dmenu que
-- el resto de los menús.

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

-- ---------- Generación de NixOS ----------

local function get_generations()
  -- No requiere root para listar, solo para cambiar.
  local output = shell("nixos-rebuild list-generations 2>/dev/null")
  local gens = {}
  for line in output:gmatch("[^\n]+") do
    table.insert(gens, line)
  end
  return gens
end

local function generation_menu()
  local gens = get_generations()
  if #gens == 0 then
    shell("notify-send 'NixOS' 'No se pudo listar generaciones' -u critical")
    return
  end
  table.insert(gens, "← Volver")
  local selection = rofi_select(gens, "Generaciones (Enter en la actual = rollback)")
  if not selection or selection == "← Volver" then return end

  -- Confirmación explícita antes de una acción destructiva/irreversible
  -- en caliente, mismo criterio que power-menu.lua usa para reboot/poweroff.
  local confirm = rofi_select({ "Sí, hacer rollback a la anterior", "Cancelar" }, "¿Confirmar?")
  if confirm ~= "Sí, hacer rollback a la anterior" then return end

  -- pkexec reutiliza el agente de polkit gráfico ya configurado — no pide
  -- contraseña en texto plano vía rofi.
  -- NOTA: esto cambia la generación activa en caliente, pero NO actualiza
  -- la entrada por defecto del bootloader — un reinicio sin especificar
  -- generación puede volver a arrancar la más reciente. Si necesitas que
  -- el rollback persista tras reiniciar, usa `nixos-rebuild switch --rollback`
  -- (con sudo) en vez de este atajo.
  os.execute("pkexec nixos-rebuild switch --rollback")
  shell("notify-send 'NixOS' 'Rollback aplicado (solo sesión actual, ver nota sobre boot)'")
end

-- ---------- Micrófono ----------

local function mic_status()
  local output = shell("wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null")
  local muted = output:match("MUTED") ~= nil
  return muted
end

local function mic_toggle()
  os.execute("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
end

-- ---------- Compartir pantalla ----------
-- SIN VERIFICAR contra una sesión de screencast real — ver advertencia
-- en el mensaje que acompaña este script. Ajustar el patrón de grep si
-- no detecta correctamente.

local function is_screensharing()
  local output = shell("pw-cli ls Node 2>/dev/null | grep -i 'screencast\\|xdg-desktop-portal'")
  return output ~= ""
end

-- ---------- Perfil de energía ----------

local function power_profile()
  local output = shell("powerprofilesctl get 2>/dev/null")
  return output:gsub("%s+$", "")
end

-- ---------- Menú principal ----------

local function main()
  local muted = mic_status()
  local sharing = is_screensharing()
  local profile = power_profile()
  local gens = get_generations()
  local current_gen = gens[#gens] or "desconocida"

  local mic_label = muted and "🎤 Micrófono: MUTEADO (clic para activar)" or "🎤 Micrófono: Activo (clic para mutear)"
  local share_label = sharing and "🔴 Compartiendo pantalla: SÍ" or "⚪ Compartiendo pantalla: No"
  local profile_label = "⚡ Perfil de energía: " .. profile
  local gen_label = "❄️  Generación actual: " .. current_gen .. "  →"

  local options = { gen_label, mic_label, share_label, profile_label, "✕ Cerrar" }
  local selection = rofi_select(options, "Sistema")
  if not selection or selection == "✕ Cerrar" then return end

  if selection == gen_label then
    generation_menu()
  elseif selection == mic_label then
    mic_toggle()
  elseif selection == profile_label then
    os.execute("lua " .. os.getenv("HOME") .. "/.config/waybar/scripts/power-profile-menu.lua")
  end
  -- share_label es solo informativo, no hay acción de toggle real posible
  -- desde aquí (depende de qué app esté compartiendo).
end

main()
