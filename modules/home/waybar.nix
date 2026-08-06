{ lib, pkgs, ... }:

{
  # pulseaudio: SOLO para el binario pactl que usa audio-output-menu.lua.
  # No es un daemon PulseAudio compitiendo con PipeWire — en un sistema
  # PipeWire-only como este, este paquete únicamente trae las
  # herramientas cliente (pactl) compatibles con el protocolo pulse que
  # expone pipewire-pulse. wpctl (wireplumber) ya cubre volumen/mute en
  # el resto del proyecto, pero no lista sinks con el detalle que pactl
  # sí da (Name/Description por separado, necesario para el menú).
  home.packages = [ pkgs.pulseaudio ];

  # Fase 3 — CLON de layout/estructura de mechabar (github.com/sejjy/mechabar),
  # adaptado: Arch -> NixOS, rofi/scripts propios -> Walker/nuestros scripts,
  # rombos/triángulos de mechabar se conservan aquí (es el mecanismo real de
  # "capas sobrepuestas" que se pidió clonar, con glifos Powerline
  # confirmados byte a byte contra los .jsonc reales del usuario, no
  # inventados). El módulo "custom/update" (checkupdates/pacman) SE
  # DESCARTÓ: no tiene equivalente razonable en NixOS.
  #
  # DECISIÓN NO VERIFICADA: "custom/distro" usa un snowflake Unicode real
  # (❄) en vez de un glifo de logo NixOS específico — no confirmé ningún
  # codepoint real para NixOS en Nerd Fonts, así que no invento uno.
  #
  # NO REPLICADO: el grupo pulseaudio#output + pulseaudio#input con drawer
  # de mechabar (control de micrófono aparte). Se mantiene un solo módulo
  # "pulseaudio" (solo salida), como ya teníamos — ampliar a control de
  # input es trabajo aparte, no lo asumí en silencio.



  # BUG REAL encontrado en pruebas: al reescribir este archivo para el
  # clon de mechabar, se perdió el bloque que despliega los scripts de
  # red/energía. Los "on-click" apuntaban a una ruta que nunca se
  # materializaba — por eso "no se mostraba nada", no era culpa de
  # Walker ni de los scripts en sí.
  xdg.configFile."waybar/scripts/network-menu.lua" = {
    source = ./waybar/scripts/network-menu.lua;
    executable = true;
  };
  xdg.configFile."waybar/scripts/power-menu.lua" = {
    source = ./waybar/scripts/power-menu.lua;
    executable = true;
  };
  xdg.configFile."waybar/scripts/bluetooth-menu.lua" = {
    source = ./waybar/scripts/bluetooth-menu.lua;
    executable = true;
  };
  xdg.configFile."waybar/scripts/power-profile-menu.lua" = {
    source = ./waybar/scripts/power-profile-menu.lua;
    executable = true;
  };
  xdg.configFile."waybar/scripts/audio-output-menu.lua" = {
    source = ./waybar/scripts/audio-output-menu.lua;
    executable = true;
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        # height/width/margin/spacing en 0: el mecanismo de "bloques sin
        # gap" de mechabar DEPENDE de esto — los divisores son los que
        # separan visualmente, no el espacio en blanco.
        height = 0;
        width = 0;
        margin = "0";
        spacing = 0;
        mode = "dock";
        reload_style_on_change = true;

        modules-left = [
          "custom/menu"
          "custom/left_div#1"
          "hyprland/workspaces"
          "custom/right_div#1"
          "hyprland/window"
        ];

        modules-center = [
          "custom/left_div#2"
          "custom/cputemp"
          "custom/left_div#3"
          "memory"
          "custom/left_div#4"
          "cpu"
          "custom/left_inv#1"
          "custom/left_div#5"
          "custom/distro"
          "custom/right_div#2"
          "custom/right_inv#1"
          "clock#time"
          "custom/right_div#3"
          "clock#date"
          "custom/right_div#4"
          "network"
          "bluetooth"
          "custom/right_div#5"
        ];

        modules-right = [
          "mpris"
          "custom/left_div#6"
          "pulseaudio"
          "custom/left_div#7"
          "backlight"
          "custom/left_div#8"
          "battery"
          "custom/left_inv#2"
          "custom/notification"
          "custom/power"
        ];

        # ---------- Divisores (glifos Powerline, confirmados byte a byte) ----------
        "custom/left_div#1"  = { format = ""; tooltip = false; };
        "custom/left_div#2"  = { format = ""; tooltip = false; };
        "custom/left_div#3"  = { format = ""; tooltip = false; };
        "custom/left_div#4"  = { format = ""; tooltip = false; };
        "custom/left_div#5"  = { format = ""; tooltip = false; };
        "custom/left_div#6"  = { format = ""; tooltip = false; };
        "custom/left_div#7"  = { format = ""; tooltip = false; };
        "custom/left_div#8"  = { format = ""; tooltip = false; };
        "custom/left_inv#1"  = { format = "▓▒"; tooltip = false; };
        "custom/left_inv#2"  = { format = "▓▒"; tooltip = false; };
        "custom/right_div#1" = { format = ""; tooltip = false; };
        "custom/right_div#2" = { format = ""; tooltip = false; };
        "custom/right_div#3" = { format = ""; tooltip = false; };
        "custom/right_div#4" = { format = ""; tooltip = false; };
        "custom/right_div#5" = { format = ""; tooltip = false; };
        "custom/right_inv#1" = { format = "▒▓"; tooltip = false; };

        # ---------- Menú / launcher (era custom/user en mechabar) ----------
        "custom/menu" = {
          format = "";
          min-length = 4;
          max-length = 4;
          tooltip-format = "Launcher";
          on-click = "rofi -show drun";
        };

        # ---------- Workspaces ----------
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
          };
          persistent-workspaces = { "*" = 5; };
          on-click = "activate";
        };

        "hyprland/window" = {
          format = "{}";
          rewrite = {
            "" = "Desktop";
            kitty = "Terminal";
            zsh = "Terminal";
            bash = "Terminal";
          };
          swap-icon-label = false;
        };

        # ---------- Sistema (temp/mem/cpu) ----------
        # custom/cputemp YA EXISTÍA y ya estaba confirmado contra `sensors`
        # real del usuario (k10temp-pci-00c3/Tctl) — se mantiene tal cual,
        # solo se reubica en el layout clonado. No se usa el módulo nativo
        # "temperature" de mechabar (thermal-zone hardcodeado, frágil).
        "custom/cputemp" = {
          # Antes: awk imprimía "+43.6°C" tal cual — no numérico, rompía
          # la evaluación de `states` (warning/critical nunca disparaban
          # de verdad). tr -d limpia signo/grado/unidad para dejar "43.6"
          # parseable; el °C se re-agrega en el propio "format". Íconos:
          # los mismos codepoints reales que ya tenías, extraídos de tu
          # archivo, no reinventados.
          exec = "sensors k10temp-pci-00c3 | awk '/Tctl/ {print $2}' | tr -d '+°C'";
          interval = 5;
          format = "󱃃 {}°C ";
          format-warning = "󰸃 {}°C ";
          format-critical = "󰸁 {}°C ";
          states = { warning = 65; critical = 80; };
          tooltip = false;
        };

        memory = {
          interval = 10;
          format = "󰘚 {percentage}% ";
          format-warning = "󰀧 {percentage}% ";
          format-critical = "󰀧 {percentage}% ";
          states = { warning = 75; critical = 90; };
          tooltip-format = "Memoria: {used:0.0f}/{total:0.0f} GiB";
        };

        cpu = {
          interval = 10;
          format = "󰍛 {usage}% ";
          format-warning = "󰀨 {usage}% ";
          format-critical = "󰀨 {usage}% ";
          states = { warning = 75; critical = 90; };
          tooltip = false;
        };

        "custom/distro" = {
          exec = "powerprofilesctl get";
          format = "";
          on-click = "lua ~/.config/waybar/scripts/power-profile-menu.lua";
          tooltip-format = "Perfil de energía: {}";
          # Sin interval a propósito (decisión del usuario): se refresca
          # solo cuando power-profile-menu.lua manda la señal tras cambiar
          # de perfil, no por polling constante.
          signal = 8;
        };

        "clock#time" = {
          format = "  {:%H:%M}";
          tooltip-format = "{:%I:%M %p}";
        };

        "clock#date" = {
          format = " 󰸗 {:%d-%m}";
          tooltip-format = "{calendar}";
          calendar = {
            mode = "month";
            mode-mon-col = 6;
            format = {
              months = "<span alpha='100%'><b>{}</b></span>";
              days = "<span alpha='90%'>{}</span>";
              weekdays = "<span alpha='80%'><i>{}</i></span>";
              today = "<span alpha='100%'><b><u>{}</u></b></span>";
            };
          };
          actions = { on-click = "mode"; };
        };

        # ---------- Red / Bluetooth: iconos de mechabar, on-click NUESTRO ----------
        network = {
          interval = 10;
          format = "󰤨";
          format-ethernet = "󰈀";
          format-wifi = "{icon}";
          format-disconnected = "󰤯";
          format-disabled = "󰤮";
          format-icons = [ "󰤟" "󰤢" "󰤥" "󰤨" ];
          tooltip-format = "Gateway: {gwaddr}";
          tooltip-format-wifi = "Red: {essid}\nIP: {ipaddr}/{cidr}\nSeñal: {signalStrength}%";
          tooltip-format-disconnected = "Wi-Fi desconectado";
          tooltip-format-disabled = "Wi-Fi deshabilitado";
          # Reemplaza los scripts de Arch de mechabar por nuestro propio
          # menú (rofi -dmenu + nmcli).
          on-click = "lua ~/.config/waybar/scripts/network-menu.lua";
        };

        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-off = "󰂲";
          format-on = "󰂰";
          format-connected = "󰂱";
          tooltip-format = "Addr: {device_address}";
          tooltip-format-disabled = "Bluetooth deshabilitado";
          tooltip-format-off = "Bluetooth apagado";
          tooltip-format-on = "Bluetooth desconectado";
          tooltip-format-connected = "Dispositivo: {device_alias}";
          # Reemplaza el script propio de mechabar por el provider nativo
          # de elephant (confirmado: "bluetooth" en `elephant listproviders`).
          on-click = "lua ~/.config/waybar/scripts/bluetooth-menu.lua";
        };

        # ---------- Multimedia ----------
        mpris = {
          format = "{player_icon} {title} - {artist}";
          format-paused = "{status_icon} {title} - {artist}";
          tooltip-format = "Reproduciendo: {title} - {artist}";
          tooltip-format-paused = "Pausado: {title} - {artist}";
          player-icons = { default = "󰏤"; };
          status-icons = { paused = "󰐊"; };
          max-length = 60;
        };

        # ---------- Volumen (simplificado: sin drawer de micrófono, ver nota arriba) ----------
        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 {volume}%";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-click-right = "lua ~/.config/waybar/scripts/audio-output-menu.lua";
          on-scroll-up = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          tooltip-format = "Salida: {desc}";
        };

        backlight = {
          format = "{icon} {percent}%";
          format-icons = [ "" "" "" "" "" "" "" "" "" ];
          on-scroll-up = "brightnessctl -e4 -n2 set 5%+";
          on-scroll-down = "brightnessctl -e4 -n2 set 5%-";
          tooltip-format = "Brillo de pantalla";
        };

        battery = {
          states = { warning = 20; critical = 10; };
          format = "{icon} {capacity}%";
          format-charging = "󰉁 {capacity}%";
          format-icons = [ "󰂎" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          format-time = "{H}h {M}min";
          tooltip-format = "Descargando: {time}";
          tooltip-format-charging = "Cargando: {time}";
        };

        # Restaurado: se había perdido al clonar el layout de mechabar
        # (que no tiene equivalente). Sin esto no hay forma de abrir el
        # panel de swaync desde la barra — snippet recomendado por el
        # propio proyecto swaync.
        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "<span foreground='#E8B860'><sup>●</sup></span>";
            none = "";
            dnd-notification = "<span foreground='#E8B860'><sup>●</sup></span>";
            dnd-none = "";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };

        "custom/power" = {
          format = "⏻";
          tooltip-format = "Menú de energía";
          on-click = "lua ~/.config/waybar/scripts/power-menu.lua";
        };
      };
    };

    style = builtins.readFile ./waybar/style.css;
  };

  systemd.user.services.waybar.Unit.ConditionEnvironment = lib.mkForce "XDG_CURRENT_DESKTOP=Hyprland";
}
