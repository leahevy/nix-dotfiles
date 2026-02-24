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
  name = "rclone";
  group = "drive";
  input = "common";
  namespace = "home";

  settings = {
    syncInterval = "10min";
    enableBackgroundSync = true;
    remotes = { };
  };

  configuration =
    context@{ config, options, ... }:
    let
      hasRemotes = self.settings.remotes != { };
      remoteNames = lib.attrNames self.settings.remotes;
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      iconThemeString = self.theme.icons.primary;
      iconThemePackage = lib.getAttr (lib.head (lib.splitString "/" iconThemeString)) pkgs;
      iconThemeName = lib.head (lib.tail (lib.splitString "/" iconThemeString));
      iconThemeBasePath = "${iconThemePackage}/share/icons/${iconThemeName}";

      remoteConfigs = lib.mapAttrs (name: cfg: {
        config = {
          type = cfg.type or "webdav";
        }
        // lib.optionalAttrs (cfg ? url) { url = cfg.url; }
        // lib.optionalAttrs (cfg ? host) { host = cfg.host; }
        // lib.optionalAttrs (cfg ? vendor) { vendor = cfg.vendor; }
        // (cfg.extraConfig or { });

        secrets = {
          user = config.sops.secrets."rclone-${name}-user".path;
          pass = config.sops.secrets."rclone-${name}-pass".path;
        };
      }) self.settings.remotes;

      remoteSecrets = lib.foldl' (
        acc: name:
        acc
        // {
          "rclone-${name}-user" = {
            format = "binary";
            sopsFile = self.config.secretsPath "rclone-${name}-user";
            mode = "0400";
          };
          "rclone-${name}-pass" = {
            format = "binary";
            sopsFile = self.config.secretsPath "rclone-${name}-pass";
            mode = "0400";
          };
        }
      ) { } remoteNames;

      rcloneConfigPath = "${config.home.homeDirectory}/.config/rclone/rclone.conf";

      sanityChecks = ''
        if [[ ! -r "${rcloneConfigPath}" ]]; then
          echo "ERROR: Rclone config not found or not readable: ${rcloneConfigPath}"
          exit 1
        fi

        ${lib.concatMapStringsSep "\n" (
          name:
          let
            userSecretPath = config.sops.secrets."rclone-${name}-user".path;
            passSecretPath = config.sops.secrets."rclone-${name}-pass".path;
          in
          ''
            if [[ ! -r "${userSecretPath}" ]]; then
              echo "ERROR: Secret file not readable for remote '${name}': ${userSecretPath}"
              exit 1
            fi
            if [[ ! -r "${passSecretPath}" ]]; then
              echo "ERROR: Secret file not readable for remote '${name}': ${passSecretPath}"
              exit 1
            fi
          ''
        ) remoteNames}
      '';

      bisyncScript = ''
        ${sanityChecks}

        ${lib.concatMapStringsSep "\n" (
          name:
          let
            cfg = self.settings.remotes.${name};
            localPath =
              if lib.hasPrefix "/" cfg.localPath then
                cfg.localPath
              else
                "${config.home.homeDirectory}/${cfg.localPath}";
          in
          ''
            if [[ ! -d "${localPath}" ]]; then
              echo "ERROR: Local sync directory does not exist for remote '${name}': ${localPath}"
              echo "Run 'rclone-sync-init' first to initialize the sync."
              exit 1
            fi
          ''
        ) remoteNames}

        SYNC_FAILED=0
        ${lib.concatMapStringsSep "\n" (
          name:
          let
            cfg = self.settings.remotes.${name};
            localPath =
              if lib.hasPrefix "/" cfg.localPath then
                cfg.localPath
              else
                "${config.home.homeDirectory}/${cfg.localPath}";
            remotePath = "${name}:${cfg.remotePath or "/"}";
            pingHost =
              if (cfg ? host) then
                cfg.host
              else
                let
                  url = cfg.url or "";
                  match = builtins.match "^[^:]+://([^/:]+).*" url;
                in
                if match != null then builtins.head match else "";
            connectivityCheck = lib.optionalString (pingHost != "") ''
              for i in {1..5}; do
                if ${pkgs.iputils}/bin/ping -c 1 -W 5 "${pingHost}" >/dev/null 2>&1; then
                  break
                fi
                if [[ $i -eq 5 ]]; then
                  echo "Cannot reach ${pingHost}, skipping ${name}"
                  return 1
                fi
                ${pkgs.coreutils}/bin/sleep $((i * 2))
              done
            '';
            checksumFlag = if (cfg.checksum or false) then "--checksum" else "";
          in
          ''
            sync_${name}() {
              ${connectivityCheck}
              ${pkgs.coreutils}/bin/mkdir -p "${localPath}"
              ${pkgs.rclone}/bin/rclone bisync "${remotePath}" "${localPath}" --verbose ${checksumFlag}
            }
            sync_${name} || SYNC_FAILED=1
          ''
        ) remoteNames}
        [[ $SYNC_FAILED -eq 0 ]]
      '';

      localPaths = lib.filter (p: !(lib.hasPrefix "/" p)) (
        lib.mapAttrsToList (_: cfg: cfg.localPath) self.settings.remotes
      );

    in
    lib.mkIf hasRemotes {
      programs.rclone = {
        enable = true;
        remotes = remoteConfigs;
        requiresUnit = "sops-nix.service";
      };

      sops.secrets = remoteSecrets;

      systemd.user.services.rclone-bisync = lib.mkMerge [
        (lib.mkIf (self.isLinux && self.linux.isModuleEnabled "storage.luks-data-drive") {
          Unit = {
            After = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
            Requires = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
          };
        })
        {
          Unit = {
            Description = "Rclone bidirectional sync";
            After = [
              "sops-nix.service"
              "rclone-config.service"
            ];
            StartLimitIntervalSec = 0;
          };
          Service = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "rclone-bisync" ''
              set -euo pipefail

              RUNTIME_DIR="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}/runtime-$(${pkgs.coreutils}/bin/id -u)}"
              LOCKDIR="$RUNTIME_DIR/rclone-bisync.lock"
              ${pkgs.coreutils}/bin/mkdir -p "$RUNTIME_DIR"

              if ! ${pkgs.coreutils}/bin/mkdir "$LOCKDIR" 2>/dev/null; then
                echo "Another rclone-bisync instance is already running. Exiting."
                exit 0
              fi

              cleanup() {
                ${pkgs.coreutils}/bin/rmdir "$LOCKDIR" 2>/dev/null || true
              }
              trap cleanup EXIT INT TERM

              ${bisyncScript}
            '';
            Restart = "on-failure";
            RestartSec = 60;
          };
        }
      ];

      systemd.user.timers.rclone-bisync = lib.mkIf self.settings.enableBackgroundSync {
        Unit.Description = "Rclone bisync timer";
        Timer = {
          OnBootSec = "2m";
          OnUnitActiveSec = self.settings.syncInterval;
          Persistent = true;
        };
        Install.WantedBy = [ "timers.target" ];
      };

      home.packages = [
        (pkgs.writeShellScriptBin "rclone-sync-now" ''
          systemctl --user start rclone-bisync.service --wait
        '')
        (pkgs.writeShellScriptBin "rclone-sync-init" ''
          set -euo pipefail

          ${sanityChecks}

          RUNTIME_DIR="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}/runtime-$(${pkgs.coreutils}/bin/id -u)}"
          LOCKDIR="$RUNTIME_DIR/rclone-bisync.lock"
          ${pkgs.coreutils}/bin/mkdir -p "$RUNTIME_DIR"

          if ! ${pkgs.coreutils}/bin/mkdir "$LOCKDIR" 2>/dev/null; then
            echo "Another rclone-bisync instance is already running. Exiting."
            exit 1
          fi

          cleanup() {
            ${pkgs.coreutils}/bin/rmdir "$LOCKDIR" 2>/dev/null || true
          }
          trap cleanup EXIT INT TERM

          ${lib.concatMapStringsSep "\n" (
            name:
            let
              cfg = self.settings.remotes.${name};
              localPath =
                if lib.hasPrefix "/" cfg.localPath then
                  cfg.localPath
                else
                  "${config.home.homeDirectory}/${cfg.localPath}";
              remotePath = "${name}:${cfg.remotePath or "/"}";
            in
            ''
              ${pkgs.coreutils}/bin/mkdir -p "${localPath}"
              ${pkgs.rclone}/bin/rclone bisync "${remotePath}" "${localPath}" --resync --verbose
            ''
          ) remoteNames}
        '')
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/rclone"
          ".cache/rclone"
        ]
        ++ localPaths;
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Shift+E" = {
              action = spawn [
                "${pkgs.bash}/bin/bash"
                "-c"
                ''
                  resolve_icon() {
                    local name="$1"
                    for size in scalable 64x64 48x48; do
                      for f in "${iconThemeBasePath}/$size"/*/"$name.svg"; do
                        [[ -f "$f" ]] && echo "$f" && return 0
                      done
                    done
                    echo "$name"
                  }

                  LOCKDIR="''${XDG_RUNTIME_DIR:-/tmp}/rclone-bisync.lock"
                  ICON_SYNC=$(resolve_icon emblem-synchronizing)
                  ICON_OK=$(resolve_icon emblem-ok-symbolic)
                  ICON_ERROR=$(resolve_icon dialog-error)

                  if [[ -d "$LOCKDIR" ]]; then
                    ${pkgs.libnotify}/bin/notify-send "Rclone" "Sync already running" --icon="$ICON_SYNC"
                  else
                    ${pkgs.libnotify}/bin/notify-send "Rclone" "Starting sync..." --icon="$ICON_SYNC"
                    if systemctl --user start rclone-bisync.service --wait; then
                      ${pkgs.libnotify}/bin/notify-send "Rclone" "Sync completed" --icon="$ICON_OK"
                    else
                      ${pkgs.libnotify}/bin/notify-send "Rclone" "Sync failed" --icon="$ICON_ERROR" --urgency=critical
                    fi
                  fi
                ''
              ];
              hotkey-overlay.title = "Apps:Rclone Sync";
            };
          };
        };
      };
    };
}
