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
    "nvidia-drm.fbdev=1"
    "nvidia.NVreg_TemporaryFilePath=/var/tmp"
    "nvidia.NVreg_DynamicPowerManagement=0x00"
    "pcie_aspm=off"
    "pcie_port_pm=off"
    "usbcore.quirks=3151:3020:gn"
  ];

  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  services.openssh.enable = true;

  # === 2. Configuración de Red ===
  networking = {
    hostName = "nixos-alons"; 
    networkmanager.enable = true;    # Habilita NetworkManager
    firewall = {
      enable = true;
      allowedTCPPorts = [ 
        5173  # Puerto de frontend en react
        25565 # Puerto para minecraft
        # 3306  # Puerto de mysql de manera publica
      ];

      # Cambiar la ip por la real
      extraCommands = ''
        iptables -A nixos-fw -p tcp --dport 3306 -s 192.168.1.50 -j ACCEPT

        iptables -A nixos-fw -p tcp --dport 3306 -s 172.23.50.42 -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 3306 -s 172.23.50.19 -j ACCEPT
        iptables -A nixos-fw -p tcp --dport 3306 -s 192.168.56.1 -j ACCEPT
      '';

      extraStopCommands = ''
        iptables -D nixos-fw -p tcp --dport 3306 -s 192.168.1.50 -j ACCEPT || true

        iptables -D nixos-fw -p tcp --dport 3306 -s 172.23.50.42 -j ACCEPT || true
        iptables -D nixos-fw -p tcp --dport 3306 -s 172.23.50.19 -j ACCEPT || true
        iptables -D nixos-fw -p tcp --dport 3306 -s 192.168.56.1 -j ACCEPT || true
      '';
    };
  };



  # === 3. Usuario y Seguridad Básica ===
  users.users.alonso = {         # Reemplaza NIXOS_USER con tu nombre
    isNormalUser = true;
    extraGroups = [
      "kvm"
      "wheel"
      "networkmanager"
      "input"
      "audio"
      "video"
    ];
    packages = with pkgs; [ tree ];
  };

  # Permite a los usuarios del grupo 'wheel' usar sudo sin contraseña.
  # security.sudo.extraRules = [{
  #   groups = [ "wheel" ];
  #   commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
  # }];

  time.timeZone = "America/Mexico_City";
  time.hardwareClockInLocalTime = true;

  i18n.defaultLocale = "es_MX.UTF-8";

  # === 4. Configuración BASE de NVIDIA (sin PRIME) ===
  # Esta es la base estable. Más tarde añadiremos las herramientas para gestionar
  # los gráficos híbridos desde el propio sistema.
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  systemd.services = {
    nvidia-suspend = {
      description = "NVIDIA system suspend actions";
      before = [ "systemd-suspend.service" ];
      requiredBy = [ "systemd-suspend.service" ];
      path = [ pkgs.kbd ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.hardware.nvidia.package.out}/bin/nvidia-sleep.sh suspend";
      };
    };

    nvidia-resume = {
      description = "NVIDIA system resume actions";
      after = [ "systemd-suspend.service" ];
      requiredBy = [ "systemd-suspend.service" ];
      path = [ pkgs.kbd ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.hardware.nvidia.package.out}/bin/nvidia-sleep.sh resume";
      };
    };

    nvidia-hibernate = {
      description = "NVIDIA system hibernate actions";
      before = [ "systemd-hibernate.service" ];
      requiredBy = [ "systemd-hibernate.service" ];
      path = [ pkgs.kbd ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${config.hardware.nvidia.package.out}/bin/nvidia-sleep.sh hibernate";
      };
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
      mesa
    ];

    extraPackages32 = with pkgs; [
      pkgsi686Linux.vulkan-loader
      pkgsi686Linux.mesa
    ];
  };

  hardware.bluetooth.enable = true;

  services.xserver.xkb.layout = "latam";
  console.useXkbConfig = true;


  # === 5. Herramientas base (sin entorno gráfico) ===
  environment.systemPackages = with pkgs; [
    vulkan-tools
    mesa-demos
    iproute2
    iw
    kitty
    uv
    gcc
    pkg-config
    git            # Necesario para clonar tu configuración
    git-lfs
    pciutils
    qalculate-qt
    brave

    vlc

    nodejs_22
    pnpm

    # Java (JDK para desarrollo móvil y backend)
    jdk25
    maven          # para proyectos Java (opcional)
    gradle         # para Android/Java (opcional)

    # Android Studio es mejor instalarlo por separado, pero puedes añadir android-tools para ADB
    android-studio
    android-tools

    godot_4

    # PHP y servidor web
    php82
    php82Packages.composer

    # Bases de datos (servidores y clientes)
    mariadb
    postgresql     # si también quieres PostgreSQL

    # Contenedores y virtualización
    docker
    podman         # alternativa sin demonio
    qemu           # para emulación

    python3

    kdePackages.kdenlive

    pixieditor
    vscode

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

  environment.localBinInPath = true;

  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    libGL
    libglvnd
    mesa

    fontconfig
    freetype
    glib

    stdenv.cc.cc.lib
    zlib
    openssl
    openssl.dev
    curl
    libxml2
    libxslt
    bzip2
    postgresql
    zstd
    icu
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  qt.enable = true;


  services.dbus.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "0.0.0.0";
      port = 3306;
    };
    ensureDatabases = [ "ipartydjs_db" ]; # Base de datos de un proyecto anterior que no se esta desarrollando por el momento (Consideracion a quitar de la configuracio en un futuro)
    ensureUsers = [
      { # Usuario que uso para conexiones de la base de datos desde mi maquina sin necesidad de sudo
        name = "desa";
        ensurePermissions = {
          "ipartydjs_db.*" = "ALL PRIVILEGES";
        };
      } {
        name = "admin";
        ensurePermissions = {
          "*.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  services.printing.enable = true;

  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  programs.java = {
    enable = true;
    package = pkgs.jdk25;
  };

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
