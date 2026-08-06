{ config, pkgs, inputs, ... }:

{
  imports = [
    ./modules/home/kitty.nix
    ./modules/home/hyprland-loader.nix
    ./modules/home/waybar.nix
    ./modules/home/rofi.nix
    ./modules/home/notifications.nix
    ./modules/home/wallpaper.nix
  ];

  home.username = "alonso";
  home.homeDirectory = "/home/alonso";

  # 26.05 es un valor de stateVersion válido en esta rama de Home Manager.
  # NO subas esto a la fecha real de instalación futura sin más — el
  # stateVersion controla defaults de compatibilidad de datos, no es un
  # "número de versión actual". Se toca solo cuando entiendes el impacto
  # de cada bump, no automáticamente.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
}
