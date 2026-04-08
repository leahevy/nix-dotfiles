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
  name = "filen";

  group = "drive";
  input = "common";

  settings = {
    syncedFolders = [
      "cloud"
    ];
  };

  on = {
    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+7" = {
              action = spawn-sh "niri-scratchpad --app-id Filen --all-windows --spawn filen-desktop";
              hotkey-overlay.title = "Apps:Filen";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Filen";
                }
              ];
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
              block-out-from = "screencast";
            }
            {
              matches = [
                {
                  app-id = "@filen/desktop";
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

    home = config: {
      home.packages = with pkgs; [
        filen-desktop
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/@filen"
        ]
        ++ lib.optionals (self.settings.syncedFolders != [ ]) self.settings.syncedFolders;
      };
    };
  };
}
