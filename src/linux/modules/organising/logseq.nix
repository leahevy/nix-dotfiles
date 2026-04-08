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
  name = "logseq";

  group = "organising";
  input = "linux";

  on = {
    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.isModuleEnabled "desktop.niri") [
        "logseq"
      ];
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+J" = {
              action = spawn-sh "niri-scratchpad --app-id Logseq --all-windows --spawn logseq";
              hotkey-overlay.title = "Apps:Logseq";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Logseq";
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
        logseq
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Logseq"
          ".logseq"
        ];
      };
    };
  };
}
