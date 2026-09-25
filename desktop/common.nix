{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;

  boot.kernelModules = [ "coretemp" "nct6775" ];

  services.xserver.videoDrivers = [ 
    "modesetting" 
  ];

  services.power-profiles-daemon.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  networking = {
    hostName = "nixos-desktop";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        5173
        25565
      ];
    };
  };

  time.timeZone = "America/Mexico_City";
  time.hardwareClockInLocalTime = true;

  i18n.defaultLocale = "es_MX.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
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

  services.xserver.enable = true;
  services.xserver.xkb.layout = "latam";

  services.printing = {
    enable = true;
    drivers = [ pkgs.gutenprint ];
    logLevel = "debug2";
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  systemd.services.cups.environment = {
    LC_NUMERIC = "C";
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.dbus.enable = true;

  users.users.alonso = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "input" "audio" "video" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
      kdePackages.kate
    ];
  };

  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxAccounts = true;
    };
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
    vulkan-tools
    mesa-demos
    kitty
    uv
    gcc
    pkg-config
    git
    git-lfs
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    pciutils
    qalculate-qt
    brave

    vlc

    nodejs_22
    pnpm

    jdk25
    maven
    gradle_9

    android-studio
    android-tools

    godot_4
    pixieditor

    php82
    php82Packages.composer

    mariadb
    postgresql

    docker

    python3

    vscode

    unrar

    antigravity
    antigravity-fhs

    htop
    btop
    fastfetch
    fd
    gdb

    onlyoffice-desktopeditors

    kdePackages.kdenlive

    darkly
    kdePackages.breeze-gtk

    scrcpy
  ];

  environment.localBinInPath = true;

  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    libGL
    libglvnd
    mesa

    libx11
    libxext
    libxi
    libxrandr
    libxrender
    libxtst
    libxcursor
    libxcomposite
    libxdamage
    libxfixes
    libxcb

    fontconfig
    freetype
    glib

    stdenv.cc.cc.lib   # cubre libstdc++.so.6 (el error más común, casi siempre necesario)
    zlib
    openssl
    openssl.dev
    curl
    libxml2
    libxslt
    bzip2
    postgresql         # da pg_config, útil si algún día usas psycopg2 (no -binary)
    zstd
    icu
  ];
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
  };

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
        error_symbol = "[✗](bold red)";
      };
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

  qt.enable = true;
  qt.platformTheme = "kde";

  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3151", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
  '';
  hardware.keyboard.qmk.enable = true;

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
