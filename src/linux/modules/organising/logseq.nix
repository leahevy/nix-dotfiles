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
    linux.overlays = [
      (final: prev: {
        logseq =
          let
            orig = prev.logseq;
          in
          final.runCommand orig.name
            {
              inherit (orig) meta;
              nativeBuildInputs = [ final.jq ];
            }
            ''
              cp -r ${orig}/. $out
              chmod -R u+w $out
              pkgJson=$out/share/logseq/resources/app/package.json
              jq '. + {"desktopName": "Logseq"}' "$pkgJson" > "$pkgJson.tmp"
              mv "$pkgJson.tmp" "$pkgJson"
              sed -i "s|${orig}/share/logseq/resources/app|$out/share/logseq/resources/app|" $out/bin/logseq
            '';
      })
    ];

    moduleEnabled.linux.desktop.niri.linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = [
        "logseq"
      ];
    };

    moduleEnabled.linux.desktop.niri.home = config: {
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
