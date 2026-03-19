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
  namespace = "home";

  settings = {
    syncedFolders = [
      "cloud"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      home.packages = with pkgs; [
        filen-desktop
      ];

      programs.niri = lib.mkIf isNiriEnabled {
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

      home.persistence."${self.persist}" = {
        directories = [
          ".config/@filen"
        ]
        ++ lib.optionals (self.settings.syncedFolders != [ ]) self.settings.syncedFolders;
      };
    };
}
