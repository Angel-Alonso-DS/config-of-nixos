#!/usr/bin/env lua
-- Menú de energía/sesión vía rofi -dmenu. Migrado desde walker --dmenu
-- tras la eliminación completa de Walker/elephant.

local options = {
  { label = " Bloquear",       cmd = "hyprlock" },
  { label = "󰒲 Suspender",      cmd = "systemctl suspend" },
  { label = " Reiniciar",      cmd = "systemctl reboot", confirm = true },
  { label = "⏻ Apagar",         cmd = "systemctl poweroff", confirm = true },
  -- Confirmado en pruebas reales: "hyprctl dispatch exit" (sintaxis
  -- vieja) está roto en Hyprland 0.55+ con config Lua. La forma
  -- correcta confirmada: pasar la expresión Lua real del dispatcher.
  { label = "󰈆 Cerrar sesión",  cmd = "hyprctl dispatch 'hl.dsp.exit()'" },
}

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

-- Solo para reiniciar/apagar: son las dos opciones destructivas
-- (pierden estado/sesión sin vuelta atrás) a un Enter de distancia de
-- un typo o un dedo torcido en la lista. Bloquear/suspender/cerrar
-- sesión no lo necesitan — son reversibles o de bajo riesgo.
local function confirm(label)
  local yes = "Sí, " .. label:gsub("^%S+%s*", ""):lower()
  local no = "Cancelar"
  local selection = rofi_select({ yes, no }, "¿Confirmar?")
  return selection == yes
end

local function main()
  local lines = {}
  for i, o in ipairs(options) do lines[i] = o.label end
  local selection = rofi_select(lines, "Energía")
  if not selection then return end

  for _, o in ipairs(options) do
    if o.label == selection then
      if o.confirm and not confirm(o.label) then return end
      os.execute(o.cmd)
      break
    end
  end
end

main()
