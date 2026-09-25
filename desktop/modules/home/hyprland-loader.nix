{ pkgs, ... }:

{
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland/hyprland.lua;

  xdg.configFile."hypr/hypridle.conf".source = ./hyprland/hypridle.conf;

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

  systemd.user.services.cliphist-wipe = {
    Unit = {
      Description = "Wipe del historial de cliphist al iniciar sesión";
      Before = [ "cliphist.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.cliphist}/bin/cliphist wipe";
    };
  };

  systemd.user.services.cliphist = {
    Unit = {
      Description = "cliphist — historial de portapapeles";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
      After = [ "cliphist-wipe.service" ];
    };
    Service = {
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store'";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
