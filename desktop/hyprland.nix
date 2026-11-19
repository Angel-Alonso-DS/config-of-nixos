{ pkgs, ... }:

import ../modules/system/hyprland.nix {
  inherit pkgs;
}
