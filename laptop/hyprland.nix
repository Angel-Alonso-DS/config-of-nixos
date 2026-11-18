{ pkgs, ... }:

import ../modules/system/hyprland.nix {
  inherit pkgs;

  nixosTags = [ "hyprland" ];

  sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };

  extraPackagesBeforePlayerctl = with pkgs; [
    brightnessctl
  ];

  extraPackagesAfterPavucontrol = with pkgs; [
    blueman
  ];

  extraPackagesAfterNetworkmanagerapplet = with pkgs; [
    wlsunset
  ];

  extraPackagesAfterHyprpicker = with pkgs; [
    adw-gtk3

    xdg-user-dirs

    wev
    xev
  ];
}
