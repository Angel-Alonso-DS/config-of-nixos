{ pkgs, ... }:

{
  # Por qué esto no pasaba solo: Plasma configura GTK/Qt automáticamente
  # al iniciar sesión (vía sus propios scripts de arranque) — mecanismo
  # que SOLO corre en una sesión Plasma, nunca en Hyprland. Como nunca
  # habíamos declarado nada de theming en Home Manager, las apps GTK/Qt
  # caían a sus defaults (claro) dentro de Hyprland.
  #
  # GTK3 clásico y GTK4/libadwaita son DOS mecanismos distintos, no uno
  # (confirmado en discusión oficial de Hyprland, github.com/hyprwm/
  # Hyprland/discussions/5867): GTK3 respeta el nombre de tema; GTK4/
  # libadwaita en la mayoría de los casos IGNORA temas custom y solo
  # responde a color-scheme=prefer-dark (te da Adwaita oscuro, NO
  # "Breeze oscuro" — Nautilus y similares no van a verse idénticos a
  # Plasma, solo van a ser oscuros).

  gtk.enable = true;
  gtk.theme = {
    name = "Adwaita-dark";
    package = pkgs.gnome-themes-extra;
  };
  # SIN VERIFICAR el nombre exacto del paquete de iconos Breeze en
  # nixpkgs 26.05 — asumido por convención (pkgs.kdePackages.* para todo
  # lo de Plasma6, ya confirmado en otros módulos de este proyecto).
  gtk.iconTheme = {
    name = "breeze";
    package = pkgs.kdePackages.breeze-icons;
  };

  # ELIMINADO: dconf.enable/dconf.settings. Causó 6 crashes simultáneos
  # (Brave, Waybar, blueman-applet, blueman-tray, nm-applet, e incluso
  # xdg-desktop-portal-gtk — el propio proceso que lee estos ajustes)
  # confirmados con libdconfsettings.so cargado en los seis, y el crash
  # PERSISTIÓ tras reiniciar sesión completa — no fue un accidente de
  # timing de un solo switch en caliente, algo estructuralmente mal con
  # cómo esto interactúa con dconf en este sistema. No reintentar esto
  # sin diagnóstico real primero (ver nota abajo).
  #
  # COSTO REAL de quitarlo: gtk.theme/gtk.iconTheme de arriba generan
  # archivos .ini planos (gtk-3.0/settings.ini, gtk-4.0/settings.ini) —
  # GTK3 va a quedar oscuro correctamente. Pero GTK4/libadwaita
  # específicamente solo responde a la señal "prefer-dark" que se
  # mandaba vía dconf — sin eso, apps GTK4 puras (Nautilus y similares)
  # pueden volver a verse claras. Se prioriza estabilidad sobre
  # cobertura completa.

  # Qt: se aprovecha que Plasma6 YA está instalado en este sistema con
  # integración Breeze real (plasma-integration) — no hace falta qt6ct
  # manual como en un setup Hyprland-only desde cero.
  #
  # SIN VERIFICAR: "kde" como valor de platformTheme.name. Confirmé que
  # la opción existe y que "gnome" fue renombrado a "adwaita" reciente
  # (código fuente real de home-manager/modules/misc/qt.nix), pero no
  # confirmé "kde" específicamente en la lista de valores válidos
  # actuales. Si falla el build, correr
  # `home-manager option qt.platformTheme.name` para ver el enum real.
  qt.enable = true;
  qt.platformTheme.name = "kde";
}
