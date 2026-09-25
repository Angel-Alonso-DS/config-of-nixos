{ pkgs, ... }:

let
  # Intérprete Lua con las librerías que el script necesita.
  luaWithLibs = pkgs.lua5_4.withPackages (ps: with ps; [ cjson luafilesystem ]);
in
{
  home.packages = [
    pkgs.awww # swww fue renombrado a awww (upstream, oct 2025) — confirmado por el
              # warning de evaluación real: "'swww' has been renamed to 'awww'"
    luaWithLibs
  ];

  xdg.configFile."hypr/scripts/wallpaper.lua" = {
    source = ./wallpaper/wallpaper.lua;
    executable = true;
  };

  # Rotación automática. Esto SÍ es responsabilidad de Nix declarar (es
  # scheduling de sistema, no lógica dinámica) — la lógica de qué imagen
  # elegir vive en el script Lua, no aquí.
  systemd.user.services."wallpaper-rotate" = {
    Unit = {
      Description = "Rotar wallpaper (selección aleatoria)";
      # awww-daemon solo corre en Hyprland (lo lanza hyprland.lua). Sin
      # esto, el timer intentaría correr en Plasma también y fallaría en
      # silencio contra un daemon que no existe ahí.
      ConditionEnvironment = "XDG_CURRENT_DESKTOP=Hyprland";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${luaWithLibs}/bin/lua %h/.config/hypr/scripts/wallpaper.lua random";
    };
  };

  systemd.user.timers."wallpaper-rotate" = {
    Unit = {
      Description = "Timer de rotación de wallpaper";
    };
    Timer = {
      OnBootSec = "2min"; # da tiempo a que awww-daemon esté listo tras el boot
      OnUnitActiveSec = "30min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
