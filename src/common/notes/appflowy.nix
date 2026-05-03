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

    ifEnabled.linux.desktop.niri.linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = [
        "appflowy"
      ];
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+Comma" = {
              action = spawn-sh "niri-scratchpad --app-id AppFlowy --all-windows --spawn appflowy";
              hotkey-overlay.title = "Apps:AppFlowy";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "AppFlowy";
                }
              ];
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
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
