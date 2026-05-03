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
  name = "appflowy";

  group = "notes";
  input = "common";

  module = {
    linux.home = config: {
      home.packages = with pkgs; [
        appflowy
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".local/share/io.appflowy.appflowy" ];
      };
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          window-rules = [
            {
              matches = [
                {
                  app-id = "AppFlowy";
                }
              ];
              block-out-from = "screencast";
            }
          ];
        };
      };
    };

    darwin.enabled = config: {
      nx.homebrew.casks = [ "appflowy" ];
    };
  };
}
