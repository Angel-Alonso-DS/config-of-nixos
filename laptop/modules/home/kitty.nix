{ config, pkgs, ... }:

{
  # Kitty se gestiona vía Home Manager porque es config 100% de usuario.
  # El paquete en sí TODAVÍA vive también en common.nix (environment.systemPackages) —
  # duplicación pendiente de resolver cuando migremos el resto de apps de usuario.
  # No lo quito de ahí en este commit para no mezclar dos cambios distintos.
  home.packages = [ pkgs.kitty ];

  # kitty.conf y current-theme.conf se copian TAL CUAL, sin pasar por
  # programs.kitty.settings (que reescribiría el archivo en otro formato
  # y perdería tus comentarios/estructura). Se deploya como texto plano.
  #
  # ADVERTENCIA (ver mensaje anterior): al quedar como symlink al Nix store,
  # `kitten themes` ya no podrá escribir sobre este archivo para cambiar de
  # tema interactivamente. Si usas esa herramienta, avísame para gestionar
  # este archivo fuera de Nix en su lugar.
  xdg.configFile = {
    "kitty/kitty.conf".source = ./kitty/kitty.conf;
    "kitty/current-theme.conf".source = ./kitty/current-theme.conf;
  };
}
