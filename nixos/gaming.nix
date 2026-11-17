{ config, pkgs, ... }:

let
  protonGE7 = pkgs.fetchzip {
    url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton7-55/GE-Proton7-55.tar.gz";
    sha256 = "sha256-6CL+9X4HBNoB/yUMIjA933XlSjE6eJC86RmwiJD6+Ws=
";
  };
in
{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  services.flatpak.enable = true;

  hardware.xone.enable = true;

  networking.networkmanager.insertNameservers = [ "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" ];
  networking.resolvconf.extraOptions = [ "single-request-reopen" ];

  systemd.tmpfiles.rules = [
    "L+ /home/alonso/.config/heroic/tools/proton/GE-Proton-nix - - - - ${pkgs.proton-ge-bin.steamcompattool}"
    "L+ /home/alonso/.config/heroic/tools/proton/GE-Proton7-nix - - - - ${protonGE7}"
  ];

  environment.systemPackages = with pkgs; [
    prismlauncher
    steam
    gamescope
    mangohud
    heroic
  ];
}
