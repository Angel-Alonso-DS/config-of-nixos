{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  # === 1. Gestor de Arranque (GRUB) y Partición EFI ===
  # Configuración diseñada para un dual boot sólido
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;   # Para máxima compatibilidad
      device = "nodev";               # Clave para sistemas UEFI
      useOSProber = true;             # Detecta Windows automáticamente
      configurationLimit = 5;         # Limita las entradas en el menú
    };
    efi.canTouchEfiVariables = true;
  };

  # === 2. Configuración de Red ===
  networking = {
    hostName = "nixos-alons";        # Ej: nixos-loq
    networkmanager.enable = true;    # Habilita NetworkManager
  };

  # === 3. Usuario y Seguridad Básica ===
  users.users.alonso = {         # Reemplaza NIXOS_USER con tu nombre
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    initialPassword = "alons";
  };

  # Permite a los usuarios del grupo 'wheel' usar sudo sin contraseña.
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
  }];

  # === 4. Configuración BASE de NVIDIA (sin PRIME) ===
  # Esta es la base estable. Más tarde añadiremos las herramientas para gestionar
  # los gráficos híbridos desde el propio sistema.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;  # A veces da problemas en laptops
    open = false;                    # Driver cerrado por estabilidad
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  boot.kernelParams = [ "nvidia_drm.modeset=1" ];

  # === 5. Herramientas base (sin entorno gráfico) ===
  environment.systemPackages = with pkgs; [
    git            # Necesario para clonar tu configuración
    vim            # Editor de texto
    curl wget      # Utilidades de red
    htop           # Monitor de procesos
    fastfetch      # Para mostrar información del sistema
  ];

  # === 6. El Ancla de Compatibilidad ===
  system.stateVersion = "25.11";
}