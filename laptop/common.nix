{ config, lib, pkgs, ... }:

let
  development = import ../modules/system/development/base.nix { inherit pkgs; };
  minecraftLan = pkgs.writeTextFile {
    name = "minecraft-lan";
    destination = "/bin/minecraft-lan";
    executable = true;
    text = "#!${pkgs.python3}/bin/python3\n" + builtins.replaceStrings
      [ "@ip@" "@iptables@" ]
      [ "${pkgs.iproute2}/bin/ip" "${pkgs.iptables}/bin/iptables" ]
      (builtins.readFile ./minecraft-lan.py);
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../profiles/office.nix
    ../profiles/multimedia.nix
  ];

  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
      useOSProber = true;
      configurationLimit = 5;
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

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Fuerza a usar conexiones más resilientes ante timeouts de red
    connect-timeout = 10;
  };

  nixpkgs.config = {
    allowUnfree = true;
    android_sdk.accept_license = true;
  };

  services.openssh.enable = true;
  services.openssh.settings = {
    PubkeyAuthentication = true;
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # === 2. Configuración de Red ===
  networking = {
    hostName = "nixos-alons"; 
    networkmanager.enable = true;    # Habilita NetworkManager
    firewall = {
      enable = true;
      allowedTCPPorts = [ 
        5173  # Puerto de frontend en react
        # 3306  # Puerto de mysql de manera publica
      ];

    };
  };

  users.users.alonso = {
    isNormalUser = true;
    extraGroups = [
      "kvm"
      "wheel"
      "networkmanager"
      "input"
      "audio"
      "video"
      "docker"
    ];
    packages = with pkgs; [ tree ];
  };

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

  services.xserver.enable = true;
  services.xserver.xkb.layout = "latam";
  console.useXkbConfig = true;


  # === 5. Herramientas base (sin entorno gráfico) ===
  environment.systemPackages = with pkgs; [
    minecraftLan
    vulkan-tools
    mesa-demos
    iproute2
    iw
    kitty
  ] ++ development.core ++ [
    pciutils
    qalculate-qt
    brave
  ] ++ config.profiles._internal.multimediaVlc ++ development.node ++ [

    # Java (JDK para desarrollo móvil y backend)
  ] ++ development.java ++ [
    gradle         # para Android/Java (opcional)

    # Android Studio es mejor instalarlo por separado, pero puedes añadir android-tools para ADB
  ] ++ development.android ++ [

    godot_4

    # PHP y servidor web
  ] ++ development.php ++ [

    # Bases de datos (servidores y clientes)
  ] ++ development.databaseClients ++ [

    # Contenedores y virtualización
  ] ++ development.containers ++ [
    podman         # alternativa sin demonio
    qemu           # para emulación

  ] ++ development.python ++ [

  ] ++ config.profiles._internal.multimediaVideoEditing ++ config.profiles._internal.multimediaImageEditing ++ development.editor ++ [

    vim
    unrar
    neovim
    curl
    wget
    lm_sensors
    htop
    btop
    img2pdf
    fastfetch
    ripgrep
    fd
  ] ++ development.debug ++ [

    # Office profile packages stay at their original position in the system path.
  ] ++ config.profiles._internal.officePackages ++ [

    darkly
    kdePackages.breeze-gtk

  ] ++ development.mobile ++ [

    wgcf
    wireguard-tools
  ];

  programs.localsend.enable = true;

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

  programs.firefox.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  services.ollama = {
    enable = true;
    # Ejemplo: cargar modelos específicos al inicio
    # loadModels = [ "llama3.2:3b" ];
  };   

  services.dbus.enable = true;

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld = {
      bind-address = "127.0.0.1";
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
    daemon.settings.features.cdi = true;
    daemon.settings = {
      dns = [ "1.1.1.1" "8.8.8.8" ];
      registry-mirrors = [ "https://mirror.gcr.io" ];
    };
  };

  hardware.nvidia-container-toolkit.enable = true;

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
    };
  };

  qt.enable = true;
  qt.platformTheme = "kde";

  environment.sessionVariables = {
    XDG_MENU_PREFIX = "plasma-";
  };

  systemd.user.services.dbus-menu-prefix-fix = {
    description = "Propaga XDG_MENU_PREFIX a D-Bus para compositores no-Plasma";
    partOf = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd XDG_MENU_PREFIX";
    };
  };

  system.stateVersion = "26.05"; # Did you read the comment?

}
