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
  name = "todoist";

  group = "todo";
  input = "linux";

  unfree = [ "todoist-electron" ];

  on = {
    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.isModuleEnabled "desktop.niri") [
        "todoist-electron"
      ];
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+Y" = {
              action = spawn-sh "niri-scratchpad --app-id Todoist --all-windows --spawn todoist-electron";
              hotkey-overlay.title = "Apps:Todo app";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "Todoist"; } ];
              max-width = 1000;
              max-height = 800;
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
              block-out-from = "screencast";
            }
          ];
        };
      };
    };

    home = config: {
      home.packages = with pkgs; [
        todoist-electron
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/Todoist" ];
      };
    };
  };
}
