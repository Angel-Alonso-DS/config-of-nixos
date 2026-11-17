{ config, pkgs, ... }:

{
  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    xwayland-satellite
  ];

  # Screencast/screenshot no funcionan solo con el portal "gtk" — niri
  # recomienda oficialmente xdg-desktop-portal-gnome para eso.
  # No toco el portal de plasma.nix, solo agrego la ruta para niri.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    config.niri.default = [ "gnome" "gtk" ];
  };

  # Reutiliza el agente de polkit de KDE, que ya tienes disponible
  # en el sistema por Plasma6 — no instala nada nuevo.
  systemd.user.services.polkit-kde-authentication-agent-1 = {
    description = "polkit-kde-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}
