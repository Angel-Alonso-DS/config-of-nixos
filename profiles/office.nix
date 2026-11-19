{ lib, pkgs, ... }:

{
  options.profiles._internal.officePackages = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ pkgs.onlyoffice-desktopeditors ];
    internal = true;
  };
}
