#!/usr/bin/env lua
-- Estado de Bluetooth para el módulo custom de waybar — solo corre
-- cuando exec-if ya confirmó que hay un controlador presente.

local function shell(cmd)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

local info = shell("bluetoothctl show 2>/dev/null")
local powered = info:match("Powered: yes") ~= nil

local devices = shell("bluetoothctl devices Connected 2>/dev/null")
local connected_name = devices:match("Device %S+ (.+)\n") or devices:match("Device %S+ (.+)$")

local text, tooltip
if not powered then
  text = "󰂲"
  tooltip = "Bluetooth apagado"
elseif connected_name and connected_name ~= "" then
  text = "󰂱"
  tooltip = "Dispositivo: " .. connected_name
else
  text = "󰂯"
  tooltip = "Bluetooth encendido, sin dispositivos conectados"
end

print(string.format('{"text": "%s", "tooltip": "%s"}', text, tooltip))
