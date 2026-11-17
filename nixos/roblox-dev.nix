{ config, lib, pkgs, ... }:

# Roblox Studio vía Vinegar — versión ajustada a tu configuración actual.
# Ya tienes en common.nix / gaming.nix: hardware.graphics (+32 bit), PipeWire
# con pulse, fuentes Noto, vulkan-tools, mesa-demos, pciutils y Flatpak.
# Aquí solo va lo que falta.
#
# Importar desde configuration.nix:
#   imports = [ ... ./gaming.nix ./roblox-dev.nix ];
#
# NO PROBADO en tu máquina: usa `nixos-rebuild build --flake .#nixos-desktop`
# antes de `switch`.
{
  environment.systemPackages = with pkgs; [
    # vinegar lo instala Home Manager (programs.vinegar.enable en home.nix)
    lsof      # para comprobar `lsof /dev/ntsync`
  ];

  # NTSync (kernel >= 6.14). Si el módulo no existe solo da un aviso al arrancar.
  boot.kernelModules = [ "ntsync" ];

  # Login por navegador (org.freedesktop.portal.OpenURI). Se fusiona con lo
  # que ya defina tu plasma.nix (no lo he visto).
  xdg.portal = {
    enable = lib.mkDefault true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fuente métricamente compatible con Arial/Times/Courier. Las Noto ya las
  # tienes en common.nix.
  fonts.packages = [ pkgs.liberation_ttf ];
}
