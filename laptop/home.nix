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

  home.packages = with pkgs; [
    swappy
    dbeaver-bin
    mongodb-atlas-cli
    gh-s
  ];

  programs.gh = {
    enable = true;
    settings = {
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
      git_protocol = "ssh";
    };
    extensions = [ pkgs.gh-s ];
  };
}
