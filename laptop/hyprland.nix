{ pkgs, ... }:

{
  system.nixos.tags = [ "hyprland" ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = [
      pkgs.xdg-desktop-portal-hyprland
    ];
    config = {
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.AppChooser" = [ "kde" ];
      };
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    GDK_BACKEND = "wayland,x11";

    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };

  environment.systemPackages = with pkgs; [
    waybar
    jq

    hyprlock
    hypridle

    wl-clipboard
    cliphist

    grimblast
    grim
    slurp

    brightnessctl
    playerctl
    pavucontrol
    blueman
    networkmanagerapplet
    wlsunset
    hyprpicker

    adw-gtk3

    xdg-user-dirs

    wev
    xev

    pipewire
    kdePackages.kio-extras
    kdePackages.kdegraphics-thumbnailers
  ];

  xdg.mime.enable = true;
  xdg.menus.enable = true;

  environment.etc."/xdg/menus/applications.menu".text = builtins.readFile "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  security.polkit.enable = true;

  security.pam.services.hyprlock = { };

  systemd.user.services.polkit-kde-authentication-agent-1 = {
    description = "polkit-kde-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };
}
