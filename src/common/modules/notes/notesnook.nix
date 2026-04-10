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
  name = "notesnook";

  group = "notes";
  input = "common";

  on = {
    moduleEnabled.linux.desktop.niri.home = config: {
      programs.niri = lib.mkIf (!(self.linux.isModuleEnabled "organising.logseq")) {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+J" = {
              action = spawn-sh "niri-scratchpad --app-id Notesnook --all-windows --spawn notesnook";
              hotkey-overlay.title = "Apps:Notes app";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Notesnook";
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
        notesnook
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Notesnook"
        ];
      };
    };
  };
}
