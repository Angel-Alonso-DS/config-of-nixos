{ pkgs, lib, ... }:

{
  home.packages = [ pkgs.walker pkgs.elephant ];

  xdg.configFile."walker/config.toml".source = ./walker/config.toml;
  xdg.configFile."walker/themes/nixos-alons/style.css".source = ./walker/style.css;

  # Corrección real, con evidencia: Walker SÍ requiere elephant corriendo
  # (confirmado por el error "Please install elephant" en producción, no
  # era opcional como asumí antes). elephant debe correr en el entorno
  # del usuario, nunca como servicio de sistema — lo dice su propia
  # documentación ("Starting a system-level systemd service will lead to
  # missing environment variables").
  systemd.user.services.elephant = {
    Unit = {
      Description = "Elephant — backend de datos para Walker";
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
    };
    Service = {
      ExecStart = "${pkgs.elephant}/bin/elephant";
      Restart = "on-failure";
    };
    # Sin Install.WantedBy: el arranque real ya no depende de
    # graphical-session.target (había una carrera confirmada en pruebas,
    # ver hyprland.lua). Ahora lo arranca explícito el hook
    # hl.on("hyprland.start"). El ConditionEnvironment se queda como red
    # de seguridad si algún día se vuelve a llamar por otra vía.
  };

  # Walker en modo servicio (--gapplication-service): arranca una vez y
  # queda residente; el bind SUPER+M en hyprland.lua llama a `walker` sin
  # flags, que actúa como cliente contra esta instancia (patrón estándar
  # de GApplication de instancia única).
  systemd.user.services.walker = {
    Unit = {
      Description = "Walker launcher (modo servicio)";
      After = [ "elephant.service" ];
      Requires = [ "elephant.service" ];
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
    };
    Service = {
      ExecStart = "${pkgs.walker}/bin/walker --gapplication-service";
      Restart = "on-failure";
    };
  };
}

