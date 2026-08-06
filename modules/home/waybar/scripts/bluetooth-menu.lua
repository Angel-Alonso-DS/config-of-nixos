#!/usr/bin/env lua
-- Menú de Bluetooth vía bluetoothctl + rofi -dmenu. Resucitado tras
-- eliminar Walker/elephant por completo — el provider nativo de
-- elephant tenía un bug confirmado y sin arreglo posible de nuestro
-- lado (power-on asimétrico: power off apagaba el radio de verdad,
-- power on no respondía). Con control directo sobre bluetoothctl no
-- dependemos de esa caja negra.
--
-- SIN VERIFICAR contra hardware real todavía — mismo tipo de
-- incertidumbre que ya resolvimos antes con el parseo de bluetoothctl.

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

local function list_devices()
  local output = shell("bluetoothctl devices")
  local devices = {}
  for mac, name in output:gmatch("Device (%S+) (.-)\n") do
    local info = shell("bluetoothctl info " .. mac)
    local connected = info:match("Connected: yes") ~= nil
    table.insert(devices, { mac = mac, name = name, connected = connected })
  end
  return devices
end

local function is_trusted(mac)
  -- Mismo patrón que is_powered/is_pairable: "bluetoothctl info <mac>"
  -- expone "Trusted: yes/no" igual que "bluetoothctl show" expone
  -- "Powered:"/"Pairable:". SIN VERIFICAR contra hardware real.
  local info = shell("bluetoothctl info " .. mac)
  return info:match("Trusted: yes") ~= nil
end

local function toggle_device(device)
  if device.connected then
    os.execute("bluetoothctl disconnect " .. device.mac)
  else
    os.execute("bluetoothctl connect " .. device.mac)
  end
end

-- Submenú de acciones para un dispositivo ya emparejado. Antes, tocar
-- un dispositivo en la lista solo alternaba conectar/desconectar; no
-- había forma de confiar/quitar confianza u olvidar uno sin salir a
-- una terminal.
local function device_actions_menu(device)
  local trusted = is_trusted(device.mac)

  local connect_label = device.connected and "󰂲 Desconectar" or "󰂯 Conectar"
  local trust_label = trusted and " Quitar confianza" or " Confiar"
  local forget_label = "🗑 Olvidar dispositivo"
  local cancel_label = "← Cancelar"

  local actions = { connect_label, trust_label, forget_label, cancel_label }
  local selection = rofi_select(actions, device.name)
  if not selection or selection == cancel_label then return end

  if selection == connect_label then
    toggle_device(device)
  elseif selection == trust_label then
    if trusted then
      os.execute("bluetoothctl untrust " .. device.mac)
    else
      os.execute("bluetoothctl trust " .. device.mac)
    end
  elseif selection == forget_label then
    -- "remove" desconecta y desempareja en un solo paso (comportamiento
    -- confirmado de bluetoothctl); no hace falta disconnect previo.
    os.execute("bluetoothctl remove " .. device.mac)
  end
end

local function scan_and_pick_new()
  os.execute("bluetoothctl --timeout 8 scan on")
  local devices = list_devices()
  return devices
end

local function is_powered()
  local output = shell("bluetoothctl show")
  return output:match("Powered: yes") ~= nil
end

local function is_pairable()
  local output = shell("bluetoothctl show")
  return output:match("Pairable: yes") ~= nil
end

local function is_discoverable()
  local output = shell("bluetoothctl show")
  return output:match("Discoverable: yes") ~= nil
end

local function main()
  local devices = list_devices()
  local lines = {}
  for i, d in ipairs(devices) do
    local status = d.connected and "● conectado" or "○ desconectado"
    lines[i] = string.format("%s — %s", d.name, status)
  end

  local powered = is_powered()
  local pairable = is_pairable()
  local discoverable = is_discoverable()

  local power_toggle_index = #lines + 1
  lines[power_toggle_index] = powered and "󰂲 Apagar Bluetooth" or "󰂰 Encender Bluetooth"

  local pairable_toggle_index = #lines + 1
  lines[pairable_toggle_index] = pairable and " Desactivar emparejable" or " Activar emparejable"

  local discoverable_toggle_index = #lines + 1
  lines[discoverable_toggle_index] = discoverable and "󰈉 Ocultarse de otros dispositivos" or "󰈈  Hacerse visible a otros dispositivos"

  table.insert(lines, " Buscar dispositivos nuevos (8s)...")

  local selection = rofi_select(lines, "Bluetooth")
  if not selection then return end

  if selection == lines[power_toggle_index] then
    if powered then
      os.execute("bluetoothctl power off")
    else
      -- CONFIRMADO NECESARIO con caso real del usuario: "bluetoothctl
      -- power on" falla en silencio (org.bluez.Error.Failed) si rfkill
      -- tiene el radio soft-blocked (pasa tras suspender, o con teclas
      -- Fn en laptops Lenovo vía el driver ideapad_bluetooth).
      local rfkill_status = shell("rfkill list bluetooth")
      if rfkill_status:match("blocked: yes") then
        os.execute("rfkill unblock bluetooth")
        os.execute("sleep 1")
      end
      os.execute("bluetoothctl power on")
    end
    return
  end

  if selection == lines[pairable_toggle_index] then
    os.execute("bluetoothctl pairable " .. (pairable and "off" or "on"))
    return
  end

  if selection == lines[discoverable_toggle_index] then
    os.execute("bluetoothctl discoverable " .. (discoverable and "off" or "on"))
    return
  end

  if selection:match("^") then
    devices = scan_and_pick_new()
    local new_lines = {}
    for i, d in ipairs(devices) do
      local status = d.connected and "● conectado" or "○ desconectado"
      new_lines[i] = string.format("%s — %s", d.name, status)
    end
    local pick = rofi_select(new_lines, "Emparejar")
    if not pick then return end
    for i, line in ipairs(new_lines) do
      if line == pick then
        os.execute("bluetoothctl pair " .. devices[i].mac)
        os.execute("bluetoothctl trust " .. devices[i].mac)
        os.execute("bluetoothctl connect " .. devices[i].mac)
        break
      end
    end
    return
  end

  for i, line in ipairs(lines) do
    if line == selection then
      device_actions_menu(devices[i])
      break
    end
  end
end

main()
