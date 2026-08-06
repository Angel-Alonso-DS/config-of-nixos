{ pkgs, ... }:

{
  system.nixos.tags = [ "hyprland" ];

  programs.hyprland = {
    enable = true;
    # UWSM (soportado nativo desde NixOS 24.11, recomendado por la wiki oficial):
    # activa graphical-session.target automáticamente al iniciar sesión.
    # Sin esto, Waybar/hypridle/el agente de polkit (todo lo que depende de
    # ese target vía systemd) NO arranca — hay un bug documentado y activo
    # en nixpkgs (issue #8547 de home-manager, reportado en esta misma
    # versión 26.05) donde graphical-session.target se queda "inactive dead"
    # si Hyprland arranca sin integración systemd.
    withUWSM = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    # Antes solo traías el portal GTK. Sin xdg-desktop-portal-hyprland,
    # el screen-share y algunos file-pickers nativos en apps GTK/Electron
    # recientes no funcionan bien bajo Hyprland. Esto estaba comentado en
    # tu archivo original — lo activo.
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      # pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
      # pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    config = {
      hyprland = {
        default = [ "hyprland" "gtk" ];
      };
    };
  };

  # SDDM se queda encendido (ya corre a nivel base vía plasma.nix). Con
  # withUWSM = true, Hyprland se registra como una entrada de sesión más
  # ("Hyprland (uwsm-managed)") en la pantalla de SDDM — no se reemplaza
  # el display manager, se le agrega una opción. Antes esto forzaba
  # sddm.enable/xserver.enable a false, lo cual habría dejado el sistema
  # sin ningún gestor de sesión gráfica al arrancar en esta specialisation.

  # Variables de entorno NVIDIA — sin cambios, tu base era correcta.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_BACKEND = "wayland,x11";

    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_NO_HARDWARE_CURSORS = "1";
    GBM_BACKEND = "nvidia-drm";
    QT_QPA_PLATFORMTHEME = "qt6ct";
  };

  environment.systemPackages = with pkgs; [
    waybar # Barra de estado
    # swaynotificationcenter y swww: eliminados de aquí. Se gestionan vía
    # Home Manager (notifications.nix, wallpaper.nix). Walker/elephant
    # fueron eliminados por completo del proyecto (ver rofi.nix) — no
    # viven ni aquí ni en Home Manager.

    hyprlock # Bloqueo de pantalla (reemplaza swaylock)
    hypridle # Gestión de inactividad (reemplaza swayidle)

    wl-clipboard
    cliphist

    # --- Capturas de pantalla ---
    grimblast
    grim
    slurp

    # --- Utilidades de sistema ---
    brightnessctl
    playerctl
    pavucontrol
    blueman
    networkmanagerapplet
    wlsunset
    hyprpicker

    # --- GTK theme ---
    adw-gtk3

    # thunar: eliminado. Se usa Dolphin, que ya llega instalado vía
    # services.desktopManager.plasma6.enable en plasma.nix — no hace falta
    # declararlo aquí. Nota: las asociaciones "Abrir con" de Dolphin no
    # funcionan fuera de una sesión Plasma (bug conocido de nixpkgs);
    # fija tus asociaciones con `xdg-mime default` si las necesitas en Hyprland.
    xdg-user-dirs

    # --- Herramientas de debug Wayland ---
    wev
    xev

    polkit_gnome
    qt6Packages.qt6ct
    kdePackages.xdg-desktop-portal-kde
  ];

  security.polkit.enable = true;

  # Requerido por hyprlock para autenticar contra PAM.
  security.pam.services.hyprlock = { };

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  /*
  systemd.user.services.xdg-desktop-portal-kde = {
    description = "xdg-desktop-portal-kde — portal KDE para diálogos y asociaciones";
    after = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    before = [ "xdg-desktop-portal.service" ];
    environment = {
      XDG_CURRENT_DESKTOP = "Hyprland";
    };
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.xdg-desktop-portal-kde}/libexec/xdg-desktop-portal-kde";
      Restart = "on-failure";
      RestartSec = 2;
      Type = "dbus";
      BusName = "org.freedesktop.impl.portal.desktop.kde";
    };
    wantedBy = [ "graphical-session.target" ];
  };
  */
}
