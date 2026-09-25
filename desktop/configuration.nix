{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./common.nix
    ./plasma.nix
    ./hyprland.nix
    # ./niri.nix
    ./virtual-machine.nix
    ./jetbrains.nix
    ./gaming.nix
    ./roblox-dev.nix
  ];
  # Montaje automático de discos
  fileSystems = {
    # Disco de backup de Linux (ext4)
    "/mnt/linux_backup" = {
      device = "/dev/disk/by-uuid/62172066-3718-44d6-b60b-dff8bb02afa3";
      fsType = "ext4";
      options = [
        "rw"           # Lectura y escritura
        "noatime"      # Mejora rendimiento
        "nofail"       # No bloquear arranque si no está presente
      ];
    };

    # Disco de datos de Windows (NTFS)
    "/mnt/datos_windows" = {
      device = "/dev/disk/by-uuid/4660957060956787";
      fsType = "ntfs-3g";
      options = [
        "rw"
        "uid=1000"     # Reemplaza con tu UID (ejecuta `id -u`)
        "gid=100"      # Reemplaza con tu GID (ejecuta `id -g`)
        "umask=022"    # Permisos 755 para carpetas y 644 para archivos
        "nofail"
      ];
    };
  };
}
