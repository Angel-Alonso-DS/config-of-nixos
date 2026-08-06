{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./common.nix
    ./jetbrains.nix
    ./plasma.nix
    ./hyprland.nix
    ./virtual-machine.nix
  ];

  nix.settings = {
    max-jobs = 2;          # reduce compilaciones en paralelo
    cores = 2;             # limita núcleos por compilación
  };

  # specialisation = {
  #  hyprland.configuration = import ./hyprland.nix { inherit config lib pkgs inputs; };
  # };
}

