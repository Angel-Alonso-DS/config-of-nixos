{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./common.nix
    ./plasma.nix
    ./hyprland.nix
    ../modules/system/jetbrains.nix
    ./gaming.nix
    ../modules/system/virtual-machine.nix
    #./hotspost.nix
  ];

  nix.settings = {
    max-jobs = 2;          # reduce compilaciones en paralelo
    cores = 2;             # limita núcleos por compilación
  };
}

