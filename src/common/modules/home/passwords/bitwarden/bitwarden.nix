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
  name = "bitwarden";

  group = "passwords";
  input = "common";
  namespace = "home";

  settings = {
    autoSyncEnabled = true;
    syncIntervalMinutes = 30;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      customPkgs = self.pkgs {
        overlays = [
          (final: prev: {
            bitwarden-cli = prev.bitwarden-cli.overrideAttrs (oldAttrs: {
              nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ prev.makeWrapper ];
              postInstall = (oldAttrs.postInstall or "") + ''
                wrapProgram $out/bin/bw \
                  --set BITWARDENCLI_APPDATA_DIR "${config.home.homeDirectory}/.config/Bitwarden-CLI"
              '';
            });
          })
        ];
      };
    in
    {
      home.packages = [
        pkgs.bitwarden
        customPkgs.bitwarden-cli
      ];

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+K" = {
              action = spawn-sh "niri-scratchpad --app-id Bitwarden --all-windows --spawn bitwarden";
              hotkey-overlay.title = "Apps:Bitwarden";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Bitwarden";
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
          ".config/Bitwarden"
          ".config/Bitwarden-CLI"
        ];
      };

      systemd.user.services = lib.mkIf self.settings.autoSyncEnabled {
        bitwarden-sync = {
          Unit = {
            Description = "Bitwarden CLI Vault Sync";
          };

          Service = {
            Type = "oneshot";
            ExecStart = "${customPkgs.bitwarden-cli}/bin/bw sync";
            Environment = [
              "BITWARDENCLI_APPDATA_DIR=${config.home.homeDirectory}/.config/Bitwarden-CLI"
            ];
            ExecCondition = pkgs.writeShellScript "check-bw-status" ''
              set -euo pipefail
              [[ -f "${config.home.homeDirectory}/.config/Bitwarden-CLI/data.json" && -r "${config.home.homeDirectory}/.config/Bitwarden-CLI/data.json" ]] || exit 1
              response=$(${customPkgs.bitwarden-cli}/bin/bw status 2>/dev/null || echo '{}')
              userId=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.userId // ""')
              [[ -n "$userId" && "$userId" != "null" ]]

              serverUrl=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.serverUrl // ""')
              if [[ -n "$serverUrl" && "$serverUrl" != "null" ]]; then
                serverHost=$(echo "$serverUrl" | ${pkgs.gnused}/bin/sed 's|https\?://||' | ${pkgs.gnused}/bin/sed 's|/.*||')
                ${pkgs.iputils}/bin/ping -c 1 -W 5 "$serverHost" >/dev/null 2>&1
              fi
            '';
          };
        };
      };

      systemd.user.timers = lib.mkIf self.settings.autoSyncEnabled {
        bitwarden-sync = {
          Unit = {
            Description = "Bitwarden CLI Vault Sync Timer";
            Requires = [ "bitwarden-sync.service" ];
          };

          Timer = {
            OnCalendar = "*:0/${toString self.settings.syncIntervalMinutes}";
            Persistent = true;
            RandomizedDelaySec = "5min";
          };

          Install = {
            WantedBy = [ "timers.target" ];
          };
        };
      };
    };
}
