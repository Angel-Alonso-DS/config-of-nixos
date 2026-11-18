# PR 05 — Desktop Environment

Esta extracción centraliza solamente configuraciones cuya equivalencia entre
`nixos-alons` y `nixos-desktop` fue comprobada byte a byte. No parametriza los
perfiles de Hyprland ni cambia las sesiones disponibles.

## Módulos compartidos

- `modules/system/plasma.nix`: SDDM Wayland, Plasma 6 y los portales KDE/GTK.
- `modules/system/hyprland.nix`: Hyprland con UWSM y XWayland, portales,
  integración KDE/Dolphin, KIO, thumbnailers, PAM de Hyprlock y el agente
  Polkit existente. Sus argumentos mantienen los extras de paquetes en la
  posición original de cada host.
- `modules/home/{kitty,rofi,notifications,wallpaper}.nix` y sus recursos:
  configuración visual idéntica de Kitty, Rofi, SwayNC y wallpaper.
- `modules/home/hyprland/hyprlock.conf`: configuración idéntica de Hyprlock.
- `modules/home/waybar/scripts/`: menús idénticos de audio, Bluetooth,
  hotspot, monitor, red, energía, captura, información del sistema y USB.

## Configuración que sigue siendo específica

- `laptop/hyprland.nix`: tag de Hyprland, variables NVIDIA y paquetes de
  brillo, Bluetooth, luz nocturna, directorios de usuario y diagnóstico.
- `desktop/hyprland.nix`: punto de carga del módulo común con los paquetes
  comunes del perfil desktop.
- `*/modules/home/hyprland-loader.nix`, `hyprland/hyprland.lua` e
  `hyprland/hypridle.conf`: monitores, workspaces, gestos, atajos, bloqueo e
  inicio de sesión. Desktop conserva `split-monitor-workspaces`; laptop
  conserva eDP-1, gestos y `SUPER+SPACE`.
- `*/modules/home/waybar.nix` y `waybar/style.css`: disposición de barras,
  sensores, batería, brillo y módulos por host. `menu-common.lua` y
  `power-profile-menu.lua` también permanecen locales por sus diferencias
  funcionales. Desktop conserva `bluetooth-status.lua`; laptop conserva el
  script generado `toggle-visibility.sh`.

Los módulos locales actualizan únicamente las rutas de recursos trasladados.
Los guards de sesión Hyprland, la integración KDE/Dolphin y el comportamiento
de los agentes no se modifican.
