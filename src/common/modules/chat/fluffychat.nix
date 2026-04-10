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
  name = "fluffychat";

  group = "chat";
  input = "common";

  on = {
    moduleEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+P" = {
              action = spawn-sh "niri-scratchpad --app-id fluffychat --all-windows --spawn fluffychat";
              hotkey-overlay.title = "Apps:Matrix chat";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "fluffychat";
                }
              ];
              min-width = 1500;
              min-height = 800;
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
        fluffychat
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/chat.fluffy.fluffychat"
        ];
      };
    };
  };
}
