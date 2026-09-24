{ config, pkgs, ... }:

{
  # 1. Configuración base para juegos en Steam
  programs.steam = {
    enable = true;
    # Abre puertos en el firewall para funcionalidades de Steam (opcional)
    remotePlay.openFirewall = true; 
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # 2. Permitir paquetes no libres (Steam y sus juegos)
  nixpkgs.config.allowUnfree = true; # O si usas un predicado más específico:
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "steam" "steam-original" "steam-unwrapped" "steam-run"
  # ];

  # 3. Soporte para control inalámbrico de Xbox (útil para Geometry Dash)
  hardware.xone.enable = true;

  # 4. Paquetes de juegos y utilidades
  environment.systemPackages = with pkgs; [
    # Launcher de Minecraft (¡alternativa recomendada!)
    prismlauncher
    
    # Cliente y launcher de Steam
    steam
    
    # Herramientas útiles
    gamescope     # Para ejecutar juegos en ventanas aisladas (opcional)
    mangohud      # Para ver FPS y rendimiento en juegos
  ];
}
