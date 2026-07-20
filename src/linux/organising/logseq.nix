args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  pinnedElectronVersion = "0.10.15";

  pinnedNixpkgsSource = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/a0374025a863d007d98e3297f6aa46cc3141c2f0.tar.gz";
    sha256 = "sha256-9mUW6gNwoN2SWc/l0fW4svPNOulXLl8ijqKyeSOGgJE=";
  };
in
{
  name = "logseq";

  group = "organising";
  input = "linux";

  module = {
    enabled =
      config:
      lib.mkIf
        (
          self.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.logseq.version
          == pinnedElectronVersion
        )
        {
          nx.flakeInputs.extra = [
            {
              name = "logseq-electron-pin";
              source = pinnedNixpkgsSource;
            }
          ];
        };

    linux.overlays = [
      (final: prev: {
        logseq =
          let
            base =
              if prev.logseq.version == pinnedElectronVersion then
                (import pinnedNixpkgsSource {
                  system = prev.stdenv.hostPlatform.system;
                  config.permittedInsecurePackages = [ "electron-39.8.10" ];
                }).logseq
              else
                prev.logseq;
          in
          final.symlinkJoin {
            name = base.name;
            paths = [ base ];
            nativeBuildInputs = [ final.jq ];
            postBuild = ''
              rm $out/share/logseq/resources/app/package.json
              jq '. + {"desktopName": "Logseq"}' \
                ${base}/share/logseq/resources/app/package.json \
                > $out/share/logseq/resources/app/package.json

              rm $out/bin/logseq
              sed "s|${base}/share/logseq/resources/app|$out/share/logseq/resources/app|" \
                ${base}/bin/logseq > $out/bin/logseq
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
