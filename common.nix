{ config, lib, pkgs, ... }:

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
  };

  boot.kernelParams = [
    "nvidia_drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "mem_sleep_default=deep"
    "nvidia.NVreg_DynamicPowerManagement=0x00"
  ];

  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  # === 2. Configuración de Red ===
  networking = {
    hostName = "nixos-alons"; 
    networkmanager.enable = true;    # Habilita NetworkManager
    firewall.allowedTCPPorts = [ 5173 ];
  };

  # === 3. Usuario y Seguridad Básica ===
  users.users.alonso = {         # Reemplaza NIXOS_USER con tu nombre
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "input"
      "audio"
      "video"
    ];
    packages = with pkgs; [ tree ];
  };

  # Permite a los usuarios del grupo 'wheel' usar sudo sin contraseña.
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
  }];

  time.timeZone = "America/Mexico_City";
  time.hardwareClockInLocalTime = true;

  i18n.defaultLocale = "es_MX.UTF-8";

  # === 4. Configuración BASE de NVIDIA (sin PRIME) ===
  # Esta es la base estable. Más tarde añadiremos las herramientas para gestionar
  # los gráficos híbridos desde el propio sistema.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;  # A veces da problemas en laptops
    # powerManagement.finegrained = true;
    open = true;                    # Driver cerrado por estabilidad
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # prime.sync.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth.enable = true;

  services.xserver.xkb.layout = "latam";
  console.useXkbConfig = true;


  # === 5. Herramientas base (sin entorno gráfico) ===
  environment.systemPackages = with pkgs; [
    kitty
    git            # Necesario para clonar tu configuración
    git-lfs
    pciutils
    qalculate-qt
    brave

    vlc

    nodejs_22
    pnpm

    # Java (JDK para desarrollo móvil y backend)
    jdk21
    maven          # para proyectos Java (opcional)
    gradle         # para Android/Java (opcional)

    # Flutter (SDK para desarrollo móvil y desktop)
    flutter
    # Android Studio es mejor instalarlo por separado, pero puedes añadir android-tools para ADB
    android-tools

    godot_4

    # PHP y servidor web
    php82
    php82Packages.composer

    # Bases de datos (servidores y clientes)
    mariadb
    # mongodb
    # mongosh        # shell moderna de MongoDB
    postgresql     # si también quieres PostgreSQL

    # Contenedores y virtualización
    docker
    # docker-compose
    podman         # alternativa sin demonio
    qemu           # para emulación

    python3

    davinci-resolve

    pixieditor
    vscode
    antigravity
    antigravity-fhs

    vim
    unrar
    neovim
    curl
    wget
    lm_sensors
    htop
    btop
    fastfetch
    ripgrep
    fd
    gdb
    kdePackages.breeze-gtk
    darkly
  ];

  qt.enable = true;


  services.dbus.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "ipartydjs_db" ];
    ensureUsers = [{
      name = "desa";
      ensurePermissions = {
        "ipartydjs_db.*" = "ALL PRIVILEGES";
      };
    }];
  };

  # services.mongodb = {
  #   enable = true;
  # };

  services.printing.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  environment.variables = {
    JAVA_HOME = "${pkgs.jdk21}";
  };

  programs.java.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji

    cascadia-code
  ];

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      # package.disabled = true;
    };
  };

  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio.override { cudaSupport = true; };
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-vaapi
    ];
  };

  system.stateVersion = "26.05"; # Did you read the comment?

}
