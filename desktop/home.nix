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
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
  programs.vinegar.enable = true;
}
