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

  on = {
    enabled = config: {
      nx.preferences.desktop.programs.videoPlayer = {
        name = "vlc";
        package = pkgs.vlc;
        openCommand = [ "vlc" ];
        openFileCommand = path: [
          "vlc"
          path
        ];
        desktopFile = "vlc.desktop";
      };
    };

    home = config: {
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
  };
}
