{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nixd
    alejandra
  ];

  # Usar la revisión de nixpkgs correspondiente al host.
  nix.nixPath = [
    "nixpkgs=${pkgs.path}"
  ];
}
