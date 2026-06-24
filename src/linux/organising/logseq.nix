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
  name = "logseq";

  group = "organising";
  input = "linux";

  module = {
    linux.overlays = [
      (final: prev: {
        logseq = final.symlinkJoin {
          name = prev.logseq.name;
          paths = [ prev.logseq ];
          nativeBuildInputs = [ final.jq ];
          postBuild = ''
            rm $out/share/logseq/resources/app/package.json
            jq '. + {"desktopName": "Logseq"}' \
              ${prev.logseq}/share/logseq/resources/app/package.json \
              > $out/share/logseq/resources/app/package.json

            rm $out/bin/logseq
            sed "s|${prev.logseq}/share/logseq/resources/app|$out/share/logseq/resources/app|" \
              ${prev.logseq}/bin/logseq > $out/bin/logseq
            chmod +x $out/bin/logseq
          '';
        };
      })
    ];

    ifEnabled.linux.desktop.niri.linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = [
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

    linux.home = config: {
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
