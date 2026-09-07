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
  name = "supersonic";
  description = "Desktop client for Navidrome and OpenSubsonic servers";

  group = "music";
  input = "linux";

  module = {
    home = config: {
      home.packages = with pkgs; [
        supersonic
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/supersonic"
          ".cache/supersonic"
        ];
      };
    };

    ifEnabled.linux.desktop.niri.linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = [
        "supersonic"
      ];
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+T" = {
              action = spawn-sh "niri-scratchpad --app-id Supersonic --all-windows --spawn supersonic";
              hotkey-overlay.title = "Apps:Supersonic";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Supersonic";
                }
              ];
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
            }
          ];
        };
      };
    };
  };
}
