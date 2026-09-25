{ pkgs, config, ... }:

{
  # theme.rasi y shared/*.rasi como archivos reales en ~/.config/rofi/,
  # no copiados aisladamente al store — así @import "shared/colors.rasi"
  # se resuelve relativo a ~/.config/rofi/ y encuentra la carpeta shared/.
  xdg.configFile = {
    "rofi/theme.rasi".source = ./rofi/theme.rasi;
    "rofi/shared/colors.rasi".source = ./rofi/shared/colors.rasi;
    "rofi/shared/fonts.rasi".source = ./rofi/shared/fonts.rasi;
  };

  programs.rofi = {
    enable = true;
    package = pkgs.rofi;

    # String, NO un path de Nix (./rofi/theme.rasi) — con un path, Home
    # Manager vuelve a copiar el archivo al store y se repite el problema.
    # Con este string, config.rasi generado apunta directo al archivo real
    # gestionado arriba por xdg.configFile.
    theme = "${config.xdg.configHome}/rofi/theme.rasi";

    # drun + run + filebrowser + window, con mode-switcher en el tema.
    extraConfig = {
      modi = "drun,run,filebrowser,window";
      show-icons = true;
      drun-display-format = "{name}";
    };
  };
}
