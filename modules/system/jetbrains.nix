# jetbrains.nix
{ config, pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.jetbrains.idea
    pkgs.scenebuilder
  ];

  programs.nix-ld.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
