{ lib, pkgs, ... }:

{
  options.profiles._internal.gamingPackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = with pkgs; [
      prismlauncher
      steam
      gamescope
      mangohud
    ];
    internal = true;
  };

  config = {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };

    hardware.xone.enable = true;
  };
}
