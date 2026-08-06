-- ============================================================
--  hyprland.lua — Fase 1
--  Reescrito desde cero (no había config previa real, solo el
--  ejemplo autogenerado con 4 líneas tocadas).
--  Deployado vía Home Manager como archivo plano — NO se genera
--  desde Nix, este es Lua real editado directamente.
-- ============================================================

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1080@144", -- confirmado por el usuario, panel del LOQ
    position = "0x0",
    scale    = "1",
})


-- TV
hl.monitor({
    output = "",
    mode = "3840x2160@30",
    position = "1920x0",
    scale = "1"
})


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local ideEditor    = "code"
local fileManager  = "dolphin" -- ya viene instalado vía plasma6, no vía Hyprland;
-- "Abrir con" no funciona fuera de sesión Plasma (bug
-- conocido de nixpkgs), asociaciones se fijan con xdg-mime.
local browser      = "brave"
local menu         = "rofi -show drun" -- Walker+elephant reemplazado por completo:
-- bugs confirmados sin arreglo posible de
-- nuestro lado (bluetooth power-on asimétrico,
-- sin provider de red). Decisión del usuario.


-------------------
---- AUTOSTART ----
-------------------

-- El archivo de prueba original SOLO lanzaba waybar. Sin hypridle no hay
-- gestión de suspensión/lock, sin swww-daemon no hay wallpaper daemon
-- corriendo. Ambos son requisitos que ya habíamos decidido para Fase 1.
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start waybar.service swaync.service hypridle.service cliphist.service")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sh -c 'sleep 1 && lua ~/.config/hypr/scripts/wallpaper.lua random'")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Gaps/bordes/blur del template original — sin tocar. Fase 3 (identidad
-- visual, paleta #85EDA4/#EDA485) es donde esto se rediseña a propósito,
-- no de paso aquí.
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 5,
        border_size = 1,
        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(668fffee)" }, angle = 45 },
            inactive_border = "rgba(999999aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",   style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

hl.config({
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
    scrolling = { fullscreen_on_one_column = true },
})

hl.config({
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = false,
    },
})


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        -- Corregido: el archivo de prueba traía "es" (España). El sistema
        -- entero (services.xserver.xkb.layout en common.nix) usa "latam".
        -- Dejar esto en "es" habría dado un layout de teclado distinto
        -- dentro de Hyprland que en el resto del sistema — inconsistencia
        -- real, no cosmética.
        kb_layout  = "latam",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",      hl.dsp.window.close())

-- Corregido: el original pasaba un comando de shell que contenía sintaxis
-- Lua como string ("hyprctl dispatch 'hl.dsp.exit()'"), lo cual no hace
-- nada. hl.dsp.exit() es un dispatcher nativo, se usa directo.
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.exit())

hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(ideEditor))
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Mover ventana dentro de la cuadrícula del layout (swap con la vecina
-- en esa dirección) — NO confirmado con un ejemplo literal de la wiki,
-- es la forma más probable dado que window.move ya acepta {workspace=..}
-- como modo alterno y "dirección l/r/u/d" es un tipo de parámetro
-- documentado compartido entre dispatchers. Probar y reportar si falla.
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

-- Redimensionar la ventana activa — sintaxis confirmada con ejemplo
-- literal de la wiki (hl.dsp.window.resize({x, y, relative=true})).
-- 20px por pulsación, repeating=true para mantener presionado.
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -20, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 20, y = 0, relative = true }),  { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0, y = 20, relative = true }),  { repeating = true })

for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Teclas multimedia / laptop
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Bloqueo manual de pantalla (hyprlock ya está instalado desde Fase 1)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Wallpaper: siguiente aleatorio / marcar-desmarcar el actual como favorito
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("lua ~/.config/hypr/scripts/wallpaper.lua random"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("lua ~/.config/hypr/scripts/wallpaper.lua toggle-favorite"))

-- Menús de Walker (red/bluetooth/energía) — ya confirmados funcionando
-- desde Waybar, se agregan también por teclado. N y SHIFT+B/SHIFT+P
-- elegidos por no chocar con binds existentes (B=browser, P=pseudo).
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd("lua ~/.config/waybar/scripts/network-menu.lua"))
hl.bind(mainMod .. " + CTRL + N",  hl.dsp.exec_cmd("lua ~/.config/waybar/scripts/audio-output-menu.lua"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("lua ~/.config/waybar/scripts/bluetooth-menu.lua"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("lua ~/.config/waybar/scripts/power-menu.lua"))
hl.bind(mainMod .. " + CTRL + P",  hl.dsp.exec_cmd("lua ~/.config/waybar/scripts/power-profile-menu.lua"))

-- Historial de portapapeles: cliphist ya estaba instalado desde Fase 1
-- (paquete sin daemon, no hacía nada). Ahora el daemon corre como
-- servicio systemd (ver hyprland-loader.nix); esto es solo el picker.
-- Patrón oficial recomendado por cliphist: list | rofi | decode | wl-copy.
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("sh -c 'cliphist list | rofi -dmenu -p Portapapeles | cliphist decode | wl-copy'"))

-- Capturas de pantalla vía grimblast (grim+slurp+hyprctl ya instalados
-- desde Fase 1, nunca se les asignó tecla hasta ahora). Sintaxis
-- verificada contra el repo oficial de grimblast y varios configs
-- reales, no inventada. "copysave" = copia a portapapeles Y guarda
-- archivo en ~/Pictures (o XDG_SCREENSHOTS_DIR si lo defines) en un
-- solo comando.
hl.bind("Print",         hl.dsp.exec_cmd("grimblast copysave area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast copysave screen"))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

-- Reglas específicas para IntelliJ / Android Studio / diálogos OAuth /
-- file pickers: NO están aquí todavía. Es Fase 3, según lo acordado.
-- Ponerlas ahora sería adivinar comportamiento sin haber probado el
-- flujo real de trabajo con esta base.
