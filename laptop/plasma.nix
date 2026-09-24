{ config, pkgs, ... }:

{
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = true;

  # Configuración de portales para KDE Plasma
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk      # Necesario para aplicaciones GTK
      pkgs.kdePackages.xdg-desktop-portal-kde # Portal nativo de KDE
    ];
    configPackages = [
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
  };
}
