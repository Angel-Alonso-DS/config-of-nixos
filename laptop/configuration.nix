{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./common.nix
    ./jetbrains.nix
    ./plasma.nix
    ./hyprland.nix
    ./gaming.nix
    ./virtual-machine.nix
    # ./hotspost.nix # Comentado hasta solucionar el problema de red y hotspost
  ];

  nix.settings = {
    max-jobs = 2;          # reduce compilaciones en paralelo
    cores = 2;             # limita núcleos por compilación
  };
}

