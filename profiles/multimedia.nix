{ config, lib, pkgs, ... }:

{
  options.profiles._internal = {
    multimediaVlc = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ pkgs.vlc ];
      internal = true;
    };

    multimediaVideoEditing = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ pkgs.kdePackages.kdenlive ];
      internal = true;
    };

    multimediaImageEditing = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ pkgs.pixieditor ];
      internal = true;
    };
  };

  config = {
    programs.obs-studio = {
      enable = true;
      package = pkgs.obs-studio.override { cudaSupport = true; };
      plugins = with pkgs.obs-studio-plugins; [
        wlrobs
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-vaapi
      ];
    };
  };
}
