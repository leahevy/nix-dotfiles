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
  name = "obsidian";

  group = "notes";
  input = "common";

  unfree = [ "obsidian" ];

  module = {
    linux.home = config: {
      home.packages = with pkgs; [
        obsidian
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/obsidian" ];
      };
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+Period" = {
              action = spawn-sh "niri-scratchpad --app-id obsidian --all-windows --spawn obsidian";
              hotkey-overlay.title = "Apps:Obsidian";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "obsidian";
                }
              ];
              open-floating = true;
              block-out-from = "screencast";
            }
          ];
        };
      };
    };

    darwin.enabled = config: {
      nx.homebrew.casks = [ "obsidian" ];
    };
  };
}
