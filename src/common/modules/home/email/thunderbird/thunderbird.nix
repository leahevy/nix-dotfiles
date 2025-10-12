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
  name = "thunderbird";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      home.packages = with pkgs-unstable; [
        thunderbird
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".thunderbird"
          ".cache/thunderbird"
          ".config/.mozilla/thunderbird"
        ];
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+O" = {
              action = spawn-sh "niri-scratchpad --app-id thunderbird --all-windows --spawn thunderbird";
              hotkey-overlay.title = "Apps:Mails";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "thunderbird"; } ];
              min-width = 1500;
              min-height = 800;
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
            }
            {
              matches = [
                {
                  app-id = "thunderbird";
                  title = ".*(Reminder|Calendar|Event|Task|Address Book|Preferences|Options|Settings).*";
                }
              ];
              open-on-workspace = "nonexistent";
              open-focused = true;
            }
            {
              matches = [ { app-id = "thunderbird"; } ];
              block-out-from = "screencast";
            }
          ];
        };
      };
    };
}
