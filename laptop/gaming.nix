{ config, ... }:

{
  imports = [ ../profiles/gaming.nix ];

  environment.systemPackages = config.profiles._internal.gamingPackages;
}
