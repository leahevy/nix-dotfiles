args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "teams";

  group = "video-conferencing";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        teams-for-linux
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/teams-for-linux"
        ];
      };
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri.settings.window-rules = [
        {
          matches = [ { app-id = "teams-for-linux"; } ];
          open-on-workspace = "1";
        }
      ];
    };
  };
}
