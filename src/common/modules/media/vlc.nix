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
    init =
      config:
      lib.mkIf self.isEnabled {
        nx.preferences.desktop.programs.videoPlayer = {
          name = "vlc";
          package = pkgs.vlc;
          openCommand = "vlc";
          openFileCommand = "vlc";
          desktopFile = "vlc.desktop";
        };
      };

    home = config: {
      home.packages = with pkgs; [
        vlc
      ];

      home.persistence."${self.persist.home}" = {
        directories = [
          ".config/vlc"
          ".local/share/vlc"
        ];
      };
    };
  };
}
