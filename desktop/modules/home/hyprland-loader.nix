{ pkgs, ... }:

{
  # Hyprland 0.55+ usa Lua nativo. No pasamos por
  # wayland.windowManager.hyprland.settings (ese módulo genera hyprlang,
  # el formato viejo deprecado) — el soporte de HM para Lua todavía está
  # "in progress" según la wiki de NixOS a esta fecha. En vez de depender
  # de eso, Nix solo copia el archivo .lua tal cual al sitio correcto.
  # El contenido es Lua real, editado directamente, sin pasar por Nix.
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland/hyprland.lua;

  # hypridle SÍ usa el formato hyprlang clásico (proyecto hermano de
  # Hyprland, no ha migrado a Lua). CONFIRMADO como obligatorio por la
  # propia wiki del proyecto — sin este archivo, hypridle aborta al
  # arrancar. Causa raíz real de ~29 crashes silenciosos.
  xdg.configFile."hypr/hypridle.conf".source = ./hyprland/hypridle.conf;

  # hypridle como servicio systemd propio con auto-restart — antes vivía
  # como proceso suelto lanzado por hl.exec_cmd("hypridle") en
  # hyprland.lua, sin supervisión: si crasheaba, nadie lo reiniciaba.
  systemd.user.services.hypridle = {
    Unit = {
      Description = "hypridle — gestor de inactividad de Hyprland";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
    };
    Service = {
      ExecStart = "${pkgs.hypridle}/bin/hypridle";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # NUEVO: daemon de cliphist — observa el portapapeles y guarda
  # historial. wl-clipboard/cliphist ya estaban instalados desde Fase 1
  # (hyprland.nix, sistema) pero nunca se arrancaba nada — el paquete
  # sin el daemon no hace nada. Mismo patrón que hypridle: servicio
  # systemd propio con auto-restart, no hl.exec_cmd suelto.
  systemd.user.services.cliphist = {
    Unit = {
      Description = "cliphist — historial de portapapeles";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
    };
    Service = {
      # wl-paste --watch cliphist store: patrón oficial recomendado por
      # el propio proyecto cliphist para alimentar el historial.
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store'";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
