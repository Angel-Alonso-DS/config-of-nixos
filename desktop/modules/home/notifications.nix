{ lib, ... }:

{
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";

      control-center-width = 400;
      control-center-height = 600;
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;

      notification-window-width = 400;
      notification-icon-size = 48;
      notification-body-image-height = 100;

      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0; # 0 = no se auto-descarta, requiere cierre manual

      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      script-fail-notify = true;

      widgets = [ "title" "dnd" "notifications" ];

      widget-config = {
        title = {
          text = "Notificaciones";
          clear-all-button = true;
        };
        dnd = {
          text = "No molestar";
        };
      };
    };

    # Pasado como string (readFile), NO como path directo — evita el bug
    # documentado en nixpkgs (issue #7839) donde style como path rompe
    # el tipo esperado por systemd.user.services.swaync.Unit.X-Restart-Triggers.
    style = builtins.readFile ./notifications/style.css;
  };

  # Mismo problema que con waybar: sin esto, swaync arranca también en
  # Plasma (graphical-session.target compartido) y compite con el
  # sistema de notificaciones nativo de KDE.
  #
  # mkForce es necesario: services.swaync YA declara su propio
  # ConditionEnvironment = "WAYLAND_DISPLAY" por defecto (para no arrancar
  # fuera de Wayland). Sin mkForce, Nix tira error de "conflicting
  # definition values" porque es un string único, no una lista que se
  # pueda fusionar. No perdemos la protección original: si
  # XDG_CURRENT_DESKTOP=Hyprland es cierto, WAYLAND_DISPLAY también lo es
  # siempre — nuestra condición es estrictamente más específica.
  systemd.user.services.swaync.Unit.ConditionEnvironment = lib.mkForce "XDG_CURRENT_DESKTOP=Hyprland";
}
