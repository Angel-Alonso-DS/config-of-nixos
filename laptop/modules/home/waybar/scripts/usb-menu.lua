#!/usr/bin/env lua
-- usb-menu.lua — unidades extraíbles (USB, SD) vía udisksctl + lsblk.
--
-- Enter      : monta si no lo está, desmonta si ya lo está.
-- Alt+Enter  : expulsar de forma segura (udisksctl power-off — apaga el
--              dispositivo por completo, no solo desmonta; solo aplica
--              sobre el disco entero, no una partición individual).
--
-- Requiere el DEMONIO udisksd corriendo (`services.udisks2.enable = true;`
-- en NixOS), no solo el binario `udisksctl` — si Plasma está instalado
-- puede que ya esté habilitado para el notificador de dispositivos de
-- Dolphin, pero hay que confirmarlo (`systemctl status udisks2`).
--
-- Solo notifica la ruta de montaje — sin abrir un gestor de archivos
-- automáticamente (decisión del usuario).

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
local TITLE = "Unidades"

-- Recorre el árbol de `lsblk -J` recolectando particiones/discos montables:
-- con sistema de archivos Y removibles (rm=true) o conectados por USB/MMC
-- (tarjetas SD). El flag `tran` no siempre se repite en las particiones
-- hijas, así que se hereda del disco padre al recorrer hacia abajo.
local function walk(node, disk_path, inherited_rm, inherited_tran, out)
  local rm = node.rm
  if rm == nil then rm = inherited_rm end
  local tran = node.tran or inherited_tran
  local this_disk = (node.type == "disk") and node.path or disk_path
  local removable = (rm == true) or tran == "usb" or tran == "mmc"

  if node.fstype and node.fstype ~= cjson.null and removable then
    out[#out + 1] = {
      device = node.path,
      disk = this_disk,
      size = node.size,
      fstype = node.fstype,
      label = (node.label and node.label ~= cjson.null) and node.label or nil,
      mountpoint = (node.mountpoint and node.mountpoint ~= cjson.null) and node.mountpoint or nil,
    }
  end

  if node.children then
    for _, child in ipairs(node.children) do
      walk(child, this_disk, rm, tran, out)
    end
  end
end

local function list_devices()
  local res = ui.run(
    "lsblk -J -o NAME,PATH,SIZE,FSTYPE,MOUNTPOINT,LABEL,RM,TYPE,TRAN",
    { timeout = 8 }
  )
  if not res.ok then return nil, ui.errmsg(res, "lsblk falló") end

  local ok, decoded = pcall(cjson.decode, res.out)
  if not ok or not decoded.blockdevices then return nil, "salida de lsblk no reconocida" end

  local out = {}
  for _, dev in ipairs(decoded.blockdevices) do
    walk(dev, nil, nil, nil, out)
  end
  return out
end

local function device_icon(d)
  if d.fstype and d.fstype:match("^vfat$") or (d.label and d.label:upper():find("SD")) then
    return I.sd_card
  end
  return I.usb
end

local function do_mount(d)
  local res = ui.run("udisksctl mount -b " .. ui.quote(d.device), { timeout = 20 })
  if res.ok then
    local mp = res.out:match("at (.+)%.?$") or res.out:match("at (.+)$")
    ui.notify(TITLE, "Montado: " .. (mp and ui.trim(mp) or d.device), { tag = "usb" })
  else
    ui.notify(TITLE, "No se pudo montar " .. (d.label or d.device) .. ": " .. ui.errmsg(res),
      { urgent = true, tag = "usb" })
  end
end

local function do_unmount(d)
  local res = ui.run("udisksctl unmount -b " .. ui.quote(d.device), { timeout = 20 })
  if res.ok then
    ui.notify(TITLE, "Desmontado: " .. (d.label or d.device), { tag = "usb" })
  else
    ui.notify(TITLE, "No se pudo desmontar " .. (d.label or d.device) .. ": " .. ui.errmsg(res),
      { urgent = true, tag = "usb" })
  end
end

-- Expulsión segura: primero desmonta si hace falta, luego apaga el disco
-- ENTERO (power-off) para que sea seguro desconectarlo físicamente.
local function do_eject(d)
  if d.mountpoint then
    local u = ui.run("udisksctl unmount -b " .. ui.quote(d.device), { timeout = 20 })
    if not u.ok then
      ui.notify(TITLE, "No se pudo desmontar antes de expulsar: " .. ui.errmsg(u), { urgent = true, tag = "usb" })
      return
    end
  end
  local target = d.disk or d.device
  local res = ui.run("udisksctl power-off -b " .. ui.quote(target), { timeout = 20 })
  if res.ok then
    ui.notify(TITLE, "Ya puedes desconectar: " .. (d.label or target), { tag = "usb" })
  else
    ui.notify(TITLE, "No se pudo expulsar " .. (d.label or target) .. ": " .. ui.errmsg(res),
      { urgent = true, tag = "usb" })
  end
end

local function main()
  if not ui.require_cmds({ "udisksctl", "lsblk" }, TITLE) then return end

  while true do
    local devices, err = list_devices()
    if not devices then
      ui.notify(TITLE, err, { urgent = true })
      return
    end
    if #devices == 0 then
      ui.notify(TITLE, "No hay unidades extraíbles conectadas", { tag = "usb" })
      return
    end

    local items = {}
    for i, d in ipairs(devices) do
      local name = d.label or d.device:match("([^/]+)$")
      local extra = d.size .. (d.mountpoint and (" · " .. d.mountpoint) or "")
      items[i] = { text = ui.row(device_icon(d), name, d.mountpoint ~= nil, extra), dev = d }
    end

    local item, _, key = ui.select(items, {
      prompt = TITLE,
      mesg = ui.mesg({ "Enter: montar/desmontar · Alt+Enter: expulsar" }),
      alt = true,
    })
    if not item then return end

    if key == "alt" then
      do_eject(item.dev)
    elseif item.dev.mountpoint then
      do_unmount(item.dev)
    else
      do_mount(item.dev)
    end
  end
end

main()
