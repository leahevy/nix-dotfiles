args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "vlc";

  group = "media";
  input = "common";
  namespace = "home";

  init =
    context@{ config, options, ... }:
    lib.mkIf self.isEnabled {
      nx.preferences.desktop.programs.videoPlayer = {
        name = "vlc";
        package = pkgs.vlc;
        openCommand = "vlc";
        openFileCommand = "vlc";
        desktopFile = "vlc.desktop";
      };
    };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        vlc
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/vlc"
          ".local/share/vlc"
        ];
      };
    };
}
