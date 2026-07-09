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
  name = "borg-backup";

  group = "storage";
  input = "linux";

  disableOnTestingVM = true;

  settings = {
    repository = {
      server = "";
      port = 22;
      user = "root";
      path = "";
    };

    schedule = "*-*-* 15:43:10";
    waitForNetwork = true;
    pingTarget = null;
    maxNetworkRetries = 30;

    compression = "auto,zstd";

    prune = {
      keep = {
        within = "1d";
        daily = 7;
        weekly = 4;
        monthly = -1;
      };
    };

    repoCheckMaxDuration = 1800;

    withData = false;
    dataPath = "/data";

    excludes = {
      persist = [ ".snapshots" ];
      nix = [ ];
      boot = [ ];
      data = [ ".snapshots" ];
    };

    pushoverNotifications = true;
    healthcheckUUID = null;
    disableOwnBackups = false;
    crossHostBorgHosts = { };
  };

  assertions = [
    {
      assertion = !self.settings.disableOwnBackups || self.settings.crossHostBorgHosts != { };
      message = "borg-backup: crossHostBorgHosts must not be empty when disableOwnBackups is true!";
    }
    {
      assertion = self.settings.disableOwnBackups || self.settings.repository.server != "";
      message = "borg-backup: repository.server must be configured";
    }
    {
      assertion = self.settings.disableOwnBackups || self.settings.repository.path != "";
      message = "borg-backup: repository.path must be configured";
    }
  ];

  module = {
    enabled =
      config:
      lib.mkIf (!self.settings.disableOwnBackups) {
        nx.linux.desktop.niri.powerMenuChecks = lib.mkIf (self.isModuleEnabled "desktop.niri") [
          {
            condition = "${pkgs.systemd}/bin/systemctl is-active --quiet borgbackup-job-system.service";
            message = "Cannot access power options while Borg backup is running!";
          }
        ];
        nx.linux.monitoring.journal-watcher.ignorePatterns = [
          { service = "borgbackup-job-system.service"; }
          { string = "borgbackup-job-system.service"; }
          { string = "BorgBackup job system"; }
        ];
      };

    home =
      config:
      let
        isHeadless = (self.host.settings.system.desktop or null) == null;
        systemBorgConfig = self.getModuleConfig "storage.borg-backup";
        repoUrl = "ssh://${systemBorgConfig.repository.user}@${systemBorgConfig.repository.server}:${toString systemBorgConfig.repository.port}${systemBorgConfig.repository.path}";
        hostname = self.host.hostname;

        borgEnvSetup = ''
          export BORG_RSH="ssh -i /run/secrets/${hostname}-borg-ssh-key -o UserKnownHostsFile=/run/secrets/${hostname}-borg-known-hosts"
          export BORG_PASSPHRASE="$(cat /run/secrets/${hostname}-borg-passphrase)"
          export BORG_REPO="${repoUrl}"
        '';

        impermanence = self.host.impermanence or false;
        persistName = lib.removePrefix "/" self.persist;

        makePatternFn = ''
          make_pattern() {
            local path="$1"
            local translated=$(translate_path "$path")
            if [[ "$translated" == "$path" ]]; then
              echo "re:.*$translated"
            else
              echo "re:^$translated"
            fi
          }
        '';

        mkTranslatePath =
          isImpermanence:
          (
            if isImpermanence then
              ''
                translate_path() {
                  local path="$1"
                  if [[ "$path" =~ ^${self.persist}(/.*) ]]; then
                    echo "${persistName}/.snapshots/${persistName}''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "${self.persist}" ]]; then
                    echo "${persistName}/.snapshots/${persistName}"
                  elif [[ "$path" =~ ^/data(/.*) ]]; then
                    echo "data/.snapshots/data''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/data" ]]; then
                    echo "data/.snapshots/data"
                  elif [[ "$path" =~ ^/nix(/.*) ]]; then
                    echo "${persistName}/.snapshots/nix''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/nix" ]]; then
                    echo "${persistName}/.snapshots/nix"
                  elif [[ "$path" =~ ^/boot(/.*) ]]; then
                    echo "boot''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/boot" ]]; then
                    echo "boot"
                  else
                    echo "$path"
                  fi
                }
              ''
            else
              ''
                translate_path() {
                  local path="$1"
                  if [[ "$path" =~ ^/data(/.*) ]]; then
                    echo "data/.snapshots/data''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/data" ]]; then
                    echo "data/.snapshots/data"
                  elif [[ "$path" =~ ^/nix(/.*) ]]; then
                    echo ".snapshots/nix''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/nix" ]]; then
                    echo ".snapshots/nix"
                  elif [[ "$path" =~ ^/boot(/.*) ]]; then
                    echo "boot''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/boot" ]]; then
                    echo "boot"
                  elif [[ "$path" =~ ^/(.+) ]]; then
                    echo ".snapshots/root/''${BASH_REMATCH[1]}"
                  elif [[ "$path" == "/" ]]; then
                    echo ".snapshots/root"
                  else
                    echo "$path"
                  fi
                }
              ''
          )
          + "\n"
          + makePatternFn;

        translatePath = mkTranslatePath impermanence;
      in
      let
        mkCrossHostFiles =
          profileName: hostEntry:
          let
            secretsBase = self.config.rootPath "profiles/nixos/${profileName}/secrets";
            runtimeSecretsBase = "${self.user.home}/.config/nx/nxconfig/profiles/nixos/${profileName}/secrets";
            sshKeyPath = runtimeSecretsBase + "/borg.ssh-key";
            passphrasePath = runtimeSecretsBase + "/borg.passphrase";
            knownHostsPath = runtimeSecretsBase + "/borg.known-hosts";
            crossBorgEnvSetup = ''
              if [[ $EUID -ne 0 ]]; then echo "Must be run as root!" >&2; exit 1; fi
              if [[ -z "''${SUDO_USER:-}" ]]; then
                echo "Error: run this script via sudo as your regular user, not directly as root!" >&2
                exit 1
              fi
              _decrypt() { sudo -u "$SUDO_USER" -- ${pkgs.sops}/bin/sops -d "$1"; }
              for _secret in ${sshKeyPath} ${knownHostsPath} ${passphrasePath}; do
                if [[ ! -f "$_secret" ]]; then
                  echo "Error: borg secret not found: $_secret" >&2
                  exit 1
                fi
              done
              _tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
              trap '${pkgs.coreutils}/bin/rm -rf "$_tmpdir"' EXIT
              _decrypt ${sshKeyPath} > "$_tmpdir/ssh-key"
              ${pkgs.coreutils}/bin/chmod 600 "$_tmpdir/ssh-key"
              _decrypt ${knownHostsPath} > "$_tmpdir/known-hosts"
              export BORG_RSH="ssh -i '$_tmpdir/ssh-key' -o UserKnownHostsFile='$_tmpdir/known-hosts'"
              BORG_PASSPHRASE=$(_decrypt ${passphrasePath})
              export BORG_PASSPHRASE
              export BORG_REPO="ssh://${hostEntry.user or "root"}@${hostEntry.server}:${
                toString (hostEntry.port or 22)
              }${hostEntry.path}"
            '';
            n = profileName;
            crossTranslatePath = mkTranslatePath (self.nixOSHosts.${profileName}.impermanence or false);
          in
          {
            home.file."${defs.binDir}/borg-backup-${n}-list" = {
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail
                ${crossBorgEnvSetup}
                ${pkgs.borgbackup}/bin/borg list
              '';
              executable = true;
            };
            home.file."${defs.binDir}/borg-backup-${n}-run" = {
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail
                ${crossBorgEnvSetup}
                ${pkgs.borgbackup}/bin/borg "$@"
              '';
              executable = true;
            };
            home.file."${defs.binDir}/borg-backup-${n}-restore" = {
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail
                if [[ $# -lt 2 ]]; then
                  echo "Usage: $0 BACKUP_NAME PATH_INSIDE_BACKUP [TARGET_DIR]"
                  exit 1
                fi
                BACKUP_NAME="$1"
                PATH_INSIDE_BACKUP="$2"
                TARGET_DIR="''${3:-./borg-restore-$(date +%Y%m%d-%H%M%S)}"
                ${crossBorgEnvSetup}
                ${crossTranslatePath}
                PATTERN=$(make_pattern "$PATH_INSIDE_BACKUP")
                if ! ${pkgs.borgbackup}/bin/borg list "::$BACKUP_NAME" "$PATTERN" >/dev/null 2>&1; then
                  echo "Error: Path '$PATH_INSIDE_BACKUP' not found in backup '$BACKUP_NAME'"
                  exit 1
                fi
                mkdir -p "$TARGET_DIR"
                cd "$TARGET_DIR"
                ${pkgs.borgbackup}/bin/borg extract "::$BACKUP_NAME" "$(translate_path "$PATH_INSIDE_BACKUP")"
                echo "Restored to: $(pwd)"
              '';
              executable = true;
            };
            home.file."${defs.binDir}/borg-backup-${n}-search" = {
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail
                if [[ $# -ne 2 ]]; then echo "Usage: $0 BACKUP_NAME PATH_GREP"; exit 1; fi
                BACKUP_NAME="$1"
                PATH_GREP="$2"
                ${crossBorgEnvSetup}
                ${crossTranslatePath}
                PATTERN=$(make_pattern "$PATH_GREP")
                ${pkgs.borgbackup}/bin/borg list "::$BACKUP_NAME" "$PATTERN" 2>/dev/null || true
              '';
              executable = true;
            };
            home.file."${defs.binDir}/borg-backup-${n}-find-archives" = {
              text = ''
                #!/usr/bin/env bash
                set -euo pipefail
                if [[ $# -ne 1 ]]; then
                  echo "Usage: $0 PATH_GREP"
                  exit 1
                fi
                PATH_GREP="$1"
                ${crossBorgEnvSetup}
                ${crossTranslatePath}
                PATTERN=$(make_pattern "$PATH_GREP")
                ${pkgs.borgbackup}/bin/borg list --short | while read -r archive; do
                  matches=$(${pkgs.borgbackup}/bin/borg list "::$archive" "$PATTERN" 2>/dev/null)
                  if [[ -n "$matches" ]]; then
                    echo "$archive:"
                    echo "$matches" | sed 's/^/  /'
                  fi
                done
              '';
              executable = true;
            };
          };
      in
      lib.foldl' (acc: extra: lib.recursiveUpdate acc extra)
        {
          assertions = lib.flatten (
            map (
              profileName:
              let
                secretsBase = self.config.rootPath "profiles/nixos/${profileName}/secrets";
              in
              [
                {
                  assertion = builtins.hasAttr profileName (self.nixOSHosts or { });
                  message = "linux.storage.borg-backup: crossHostBorgHosts.${profileName} does not match any NixOS host!";
                }
                {
                  assertion = builtins.pathExists (secretsBase + "/borg.ssh-key");
                  message = "linux.storage.borg-backup: crossHostBorgHosts.${profileName}: borg.ssh-key not found in nxconfig secrets!";
                }
                {
                  assertion = builtins.pathExists (secretsBase + "/borg.passphrase");
                  message = "linux.storage.borg-backup: crossHostBorgHosts.${profileName}: borg.passphrase not found in nxconfig secrets!";
                }
                {
                  assertion = builtins.pathExists (secretsBase + "/borg.known-hosts");
                  message = "linux.storage.borg-backup: crossHostBorgHosts.${profileName}: borg.known-hosts not found in nxconfig secrets!";
                }
              ]
            ) (lib.attrNames self.settings.crossHostBorgHosts)
          );
        }
        (
          lib.optionals (!self.settings.disableOwnBackups) [
            {

              home.file."${defs.binDir}/borg-backup-status" = {
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  GREEN='\033[1;32m'
                  BLUE='\033[1;34m'
                  RED='\033[1;31m'
                  YELLOW='\033[1;33m'
                  NC='\033[0m'

                  echo -e "''${BLUE}=== BORG BACKUP STATUS ===''${NC}"
                  echo

                  echo -e "''${GREEN}=== TIMER STATUS ===''${NC}"
                  systemctl status borgbackup-job-system.timer --no-pager --lines=3 2>/dev/null || echo "Borg timer not found"
                  echo

                  echo -e "''${GREEN}=== LAST BACKUP STATUS ===''${NC}"
                  if systemctl is-active --quiet borgbackup-job-system.service; then
                    echo -e "''${YELLOW}Backup currently running...''${NC}"
                  else
                    systemctl status borgbackup-job-system.service --no-pager --lines=5 2>/dev/null || true
                  fi
                  echo

                  echo -e "''${GREEN}=== RECENT BACKUP LOGS (last 10 lines) ===''${NC}"
                  nx-user-notify-logs recent 2>/dev/null | grep -i "borg" || echo "No backup logs found"
                  echo

                  if ! systemctl is-active --quiet borgbackup-job-system.service && systemctl is-failed --quiet borgbackup-job-system.service; then
                    echo -e "''${RED}=== BACKUP SERVICE FAILURE LOGS ===''${NC}"
                    journalctl -u borgbackup-job-system.service --no-pager --lines=15 --reverse 2>/dev/null
                    echo
                  fi

                  echo
                  echo -e "''${BLUE}Press any key to exit...''${NC}"
                  read -n 1
                '';
                executable = true;
              };

              home.file."${defs.binDir}/borg-backup-list" = {
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  if [[ $EUID -ne 0 ]]; then
                    echo "Must be run as root!"
                    exit 1
                  fi

                  ${borgEnvSetup}

                  borg list
                '';
                executable = true;
              };

              home.file."${defs.binDir}/borg-backup-restore" = {
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  if [[ $EUID -ne 0 ]]; then
                    echo "Must be run as root!"
                    exit 1
                  fi

                  if [[ $# -lt 2 ]]; then
                    echo "Usage: $0 BACKUP_NAME PATH_INSIDE_BACKUP [TARGET_LOCATION]"
                    exit 1
                  fi

                  BACKUP_NAME="$1"
                  PATH_INSIDE_BACKUP="$2"
                  TARGET_LOCATION="''${3:-./borg-backup-restore-$(date +%Y%m%d-%H%M%S)}"

                  ${borgEnvSetup}
                  ${translatePath}

                  PATTERN=$(make_pattern "$PATH_INSIDE_BACKUP")

                  if ! borg list "::$BACKUP_NAME" "$PATTERN" >/dev/null 2>&1; then
                    echo "Error: Path '$PATH_INSIDE_BACKUP' not found in backup '$BACKUP_NAME'"
                    exit 1
                  fi

                  mkdir -p "$TARGET_LOCATION"
                  cd "$TARGET_LOCATION"

                  borg extract "::$BACKUP_NAME" "$(translate_path "$PATH_INSIDE_BACKUP")"
                  echo "Restored to: $(pwd)"
                '';
                executable = true;
              };

              home.file."${defs.binDir}/borg-backup-search" = {
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  if [[ $EUID -ne 0 ]]; then
                    echo "Must be run as root!"
                    exit 1
                  fi

                  if [[ $# -ne 2 ]]; then
                    echo "Usage: $0 BACKUP_NAME PATH_GREP"
                    exit 1
                  fi

                  BACKUP_NAME="$1"
                  PATH_GREP="$2"

                  ${borgEnvSetup}
                  ${translatePath}

                  PATTERN=$(make_pattern "$PATH_GREP")

                  borg list "::$BACKUP_NAME" "$PATTERN" 2>/dev/null || true
                '';
                executable = true;
              };

              home.file."${defs.binDir}/borg-backup-find-archives" = {
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  if [[ $EUID -ne 0 ]]; then
                    echo "Must be run as root!"
                    exit 1
                  fi

                  if [[ $# -ne 1 ]]; then
                    echo "Usage: $0 PATH_GREP"
                    exit 1
                  fi

                  PATH_GREP="$1"

                  ${borgEnvSetup}
                  ${translatePath}

                  PATTERN=$(make_pattern "$PATH_GREP")

                  borg list --short | while read -r archive; do
                    matches=$(borg list "::$archive" "$PATTERN" 2>/dev/null)
                    if [[ -n "$matches" ]]; then
                      echo "$archive:"
                      echo "$matches" | sed 's/^/  /'
                    fi
                  done
                '';
                executable = true;
              };

              home.file."${defs.binDir}/borg-backup-run" = {
                text = ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  if [[ $EUID -ne 0 ]]; then
                    echo "Must be run as root!"
                    exit 1
                  fi

                  ${borgEnvSetup}

                  borg "$@"
                '';
                executable = true;
              };

              home.file."${defs.binDir}/borg-backup-trigger-manually" = {
                text = ''
                            #!/usr/bin/env bash
                            set -euo pipefail

                            if [[ $EUID -eq 0 ]]; then
                              echo "Must be run as user!"
                              exit 1
                            fi

                            if systemctl is-active --quiet borgbackup-job-system.service; then
                              echo "Error: Backup is already running!"
                              exit 1
                            fi

                            echo "Starting backup manually..."
                            sudo touch /tmp/nx-force-backup
                            sudo systemctl start borgbackup-job-system.service
                            echo "Success: Backup triggered manually"

                  ${
                    if isHeadless then
                      ""
                    else
                      "${self.notifyUser {
                        inherit pkgs;
                        title = "Backup Triggered";
                        body = "Manual backup triggered - will start in 10 minutes";
                        icon = "archive";
                        urgency = "normal";
                        validation = { inherit config; };
                      }}"
                  }
                '';
                executable = true;
              };
            }
          ]
          ++ lib.mapAttrsToList mkCrossHostFiles self.settings.crossHostBorgHosts
        );

    ifEnabled.linux.desktop.niri.home =
      config:
      let
        terminal = config.nx.preferences.desktop.programs.additionalTerminal;
        terminalShellCmd =
          cmd:
          lib.escapeShellArgs (helpers.runWithAbsolutePath config terminal terminal.openShellCommand cmd);
      in
      lib.mkIf (!self.settings.disableOwnBackups) {
        programs.niri = {
          settings = {
            binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+B" = {
                action = spawn-sh (terminalShellCmd "borg-backup-status");
                hotkey-overlay.title = "System:Backup status";
              };
            };
          };
        };
      };

    system =
      config:
      let
        pushover = config.nx.linux.notifications.pushover;
        hcFinalUrl = config.nx.linux.server.healthchecks.healthchecksFinalChecksURL;
        hcBaseUrl = config.nx.linux.server.healthchecks.healthchecksBaseUrl;
        hcUrl =
          if self.settings.healthcheckUUID != null && hcFinalUrl != null then
            "${hcBaseUrl}/checks/${self.settings.healthcheckUUID}/details/"
          else
            hcFinalUrl;
        hcUrlTitle =
          if hcUrl == null then
            null
          else if self.settings.healthcheckUUID != null && hcFinalUrl != null then
            "View Borg check"
          else
            "View healthchecks";
        repoUrl = "ssh://${self.settings.repository.user}@${self.settings.repository.server}:${toString self.settings.repository.port}${self.settings.repository.path}";
        snapshotBase = self.persistPath ".snapshots";

        pingTarget =
          if self.settings.pingTarget != null then
            self.settings.pingTarget
          else
            self.settings.repository.server;

        networkWaitScript = lib.optionalString self.settings.waitForNetwork ''
          ${pkgs.coreutils}/bin/echo "Waiting for network connectivity..."
          retries=0
          max_retries=${toString self.settings.maxNetworkRetries}
          until ${pkgs.iputils}/bin/ping -c1 -q ${pingTarget} >/dev/null 2>&1; do
            retries=$((retries + 1))
            if [ $retries -ge $max_retries ]; then
              ${pkgs.coreutils}/bin/echo "Network connectivity failed after $max_retries attempts"
              exit 1
            fi
            ${pkgs.coreutils}/bin/echo "Network not ready, waiting 30s... (attempt $retries/$max_retries)"
            ${pkgs.coreutils}/bin/sleep 30
          done
          ${pkgs.coreutils}/bin/echo "Network connectivity verified"
        '';

        cleanupSnapshotScript =
          {
            snapshotName,
            snapshotDir,
            canFail ? false,
          }:
          ''
            if ${pkgs.btrfs-progs}/bin/btrfs subvolume show ${snapshotDir}/${snapshotName} 2>/dev/null; then
              ${pkgs.coreutils}/bin/echo "Cleaning up ${snapshotName} backup snapshot..."
              ${pkgs.btrfs-progs}/bin/btrfs subvolume delete ${snapshotDir}/${snapshotName} ${
                if canFail then "|| true" else ""
              };
            fi
          '';

        createSnapshotScript =
          {
            volume,
            snapshotName,
            snapshotDir,
          }:
          ''
            ${pkgs.coreutils}/bin/mkdir -p ${snapshotDir}
            ${cleanupSnapshotScript { inherit snapshotName snapshotDir; }}
            ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r ${volume} ${snapshotDir}/${snapshotName}
          '';

        checkAutoUpgradeRunningScript = ''
          check_auto_upgrade_running() {
            local auto_upgrade_state=$(${pkgs.systemd}/bin/systemctl show nx-auto-upgrade.service -p ActiveState --value)
            if [[ "$auto_upgrade_state" != "inactive" ]]; then
              ${pkgs.coreutils}/bin/touch /tmp/nx-backup-no-success
              ${logScript "info" "INFO: Auto-upgrade is currently running (state: $auto_upgrade_state), skipping backup"}
              exit 0
            fi
          }
        '';

        checkDailyBackupCompleteScript = ''
          check_daily_backup_complete() {
            if [[ ! -f "/tmp/nx-force-backup" ]]; then
              TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
              if ${pkgs.systemd}/bin/journalctl -u borg-backup-log-success.service --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" -q --grep="SUCCESS: System backup completed successfully" >/dev/null 2>&1; then
                ${pkgs.coreutils}/bin/touch /tmp/nx-backup-skipped
                ${pkgs.coreutils}/bin/touch /tmp/nx-backup-no-success
                exit 0
              fi
            fi
            ${pkgs.coreutils}/bin/rm -f /tmp/nx-force-backup
          }
        '';

        logScript =
          level: message:
          let
            userNotifyEnabled = (self.isModuleEnabled "notifications.user-notify");
            pushoverEnabled = self.settings.pushoverNotifications;

            userNotifyTitle =
              if userNotifyEnabled then
                if lib.hasPrefix "STARTED:" message then
                  "Borg Backup (starting)"
                else if lib.hasPrefix "SUCCESS:" message then
                  "Borg Backup (completed)"
                else if lib.hasPrefix "FAILURE:" message then
                  "Borg Backup (failed)"
                else if lib.hasPrefix "INFO:" message then
                  "Borg Backup (info)"
                else
                  "Borg Backup"
              else
                "";

            userNotifyMessage =
              if userNotifyEnabled then
                if lib.hasPrefix "STARTED:" message then
                  lib.removePrefix "STARTED: " message
                else if lib.hasPrefix "SUCCESS:" message then
                  lib.removePrefix "SUCCESS: " message
                else if lib.hasPrefix "FAILURE:" message then
                  lib.removePrefix "FAILURE: " message
                else if lib.hasPrefix "INFO:" message then
                  lib.removePrefix "INFO: " message
                else
                  message
              else
                "";

            userNotifyIcon =
              if userNotifyEnabled then
                if lib.hasPrefix "STARTED:" message then
                  "folder-sync"
                else if lib.hasPrefix "SUCCESS:" message then
                  "checkmark"
                else if lib.hasPrefix "FAILURE:" message then
                  "dialog-error"
                else if lib.hasPrefix "INFO:" message then
                  "folder-sync"
                else
                  "folder-sync"
              else
                "";

            pushoverType =
              if lib.hasPrefix "STARTED:" message then
                "started"
              else if lib.hasPrefix "SUCCESS:" message then
                "success"
              else if lib.hasPrefix "FAILURE:" message then
                "failed"
              else if lib.hasPrefix "INFO:" message && lib.hasInfix "Auto-upgrade" message then
                "info"
              else
                null;

            shouldSendPushover = pushoverEnabled && pushoverType != null;

            pushoverMessage =
              if lib.hasPrefix "STARTED:" message then
                lib.removePrefix "STARTED: " message
              else if lib.hasPrefix "SUCCESS:" message then
                lib.removePrefix "SUCCESS: " message
              else if lib.hasPrefix "FAILURE:" message then
                lib.removePrefix "FAILURE: " message
              else if lib.hasPrefix "INFO:" message && lib.hasInfix "Auto-upgrade" message then
                lib.removePrefix "INFO: " message
              else
                message;
          in
          ''
            ${lib.optionalString userNotifyEnabled (
              self.notifyUser {
                inherit pkgs;
                title = userNotifyTitle;
                body = userNotifyMessage;
                icon = userNotifyIcon;
                urgency = helpers.loggerLevelToNotifyLevel level;
                validation = { inherit config; };
              }
            )}

            ${lib.optionalString shouldSendPushover (
              pushover.send {
                title = "Borg-Backup";
                message = pushoverMessage;
                type = pushoverType;
                url = hcUrl;
                urlTitle = hcUrlTitle;
                shellVars = true;
              }
            )}
            echo "${message}" ${if level == "err" then ">&2" else ""}
          '';

        impermanence = self.host.impermanence or false;

        rootSnapshotName = if impermanence then "persist" else "root";

        backupPaths = [
          "${snapshotBase}/${rootSnapshotName}"
          "${snapshotBase}/nix"
          "/boot"
        ]
        ++ lib.optional self.settings.withData "${self.settings.dataPath}/.snapshots/data";

        allExcludes =
          (map (exclude: "${snapshotBase}/${rootSnapshotName}/${exclude}") self.settings.excludes.persist)
          ++ (map (exclude: "${snapshotBase}/nix/${exclude}") self.settings.excludes.nix)
          ++ (map (exclude: "/boot/${exclude}") self.settings.excludes.boot)
          ++ lib.optionals self.settings.withData (
            map (exclude: "${self.settings.dataPath}/.snapshots/data/${exclude}") self.settings.excludes.data
          );

      in
      lib.mkIf (!self.settings.disableOwnBackups) {
        environment.systemPackages = [
          pkgs.borgbackup
          pkgs.btrfs-progs
        ];

        sops.secrets."${self.host.hostname}-borg-ssh-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "borg.ssh-key";
          mode = "0400";
          owner = "root";
          group = "root";
        };

        sops.secrets."${self.host.hostname}-borg-passphrase" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "borg.passphrase";
          mode = "0400";
          owner = "root";
          group = "root";
        };

        sops.secrets."${self.host.hostname}-borg-known-hosts" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "borg.known-hosts";
          mode = "0644";
          owner = "root";
          group = "root";
        };

        services.borgbackup.jobs.system = {
          repo = repoUrl;
          compression = self.settings.compression;
          encryption = {
            mode = "repokey-blake2";
            passCommand = "cat ${config.sops.secrets."${self.host.hostname}-borg-passphrase".path}";
          };
          environment = {
            BORG_RSH = "ssh -i ${
              config.sops.secrets."${self.host.hostname}-borg-ssh-key".path
            } -o UserKnownHostsFile=${config.sops.secrets."${self.host.hostname}-borg-known-hosts".path}";
          };
          inhibitsSleep = true;
          startAt = self.settings.schedule;
          persistentTimer = true;
          user = "root";
          group = "root";

          doInit = true;
          prune.keep = self.settings.prune.keep;

          preHook = ''
            ${pkgs.coreutils}/bin/rm -f /tmp/nx-backup-skipped /tmp/nx-backup-completed /tmp/nx-backup-no-success
            ${checkDailyBackupCompleteScript}
            check_daily_backup_complete
            ${pkgs.coreutils}/bin/echo "Waiting 10 minutes for system readiness..."
            ${pkgs.coreutils}/bin/sleep 600
            ${checkAutoUpgradeRunningScript}
            check_auto_upgrade_running
            ${networkWaitScript}
            ${logScript "info" "STARTED: System backup starting"}
            ${createSnapshotScript {
              volume = if impermanence then self.persist else "/";
              snapshotName = rootSnapshotName;
              snapshotDir = snapshotBase;
            }}
            ${createSnapshotScript {
              volume = "/nix";
              snapshotName = "nix";
              snapshotDir = snapshotBase;
            }}
            ${lib.optionalString self.settings.withData (createSnapshotScript {
              volume = self.settings.dataPath;
              snapshotName = "data";
              snapshotDir = "${self.settings.dataPath}/.snapshots";
            })}
            ${pkgs.coreutils}/bin/echo "Snapshots created - starting backup..."
          '';

          paths = backupPaths;
          exclude = allExcludes;

          postHook = ''
            ${pkgs.coreutils}/bin/touch /tmp/nx-backup-completed
            ${cleanupSnapshotScript {
              snapshotName = rootSnapshotName;
              snapshotDir = snapshotBase;
              canFail = true;
            }}
            ${cleanupSnapshotScript {
              snapshotName = "nix";
              snapshotDir = snapshotBase;
              canFail = true;
            }}
            ${lib.optionalString self.settings.withData (cleanupSnapshotScript {
              snapshotName = "data";
              snapshotDir = "${self.settings.dataPath}/.snapshots";
              canFail = true;
            })}
            if [[ ! -f "/tmp/nx-backup-skipped" ]]; then
              ${pkgs.coreutils}/bin/echo "All snapshots deleted successfully"
            fi
            ${pkgs.coreutils}/bin/rm -f /tmp/nx-backup-skipped
            if [ "$exitStatus" -eq 0 ]; then
              ${pkgs.borgbackup}/bin/borg check --repository-only --verbose --max-duration=${toString self.settings.repoCheckMaxDuration}
            fi
          '';

        };

        systemd.services.borg-backup-log-failure = {
          description = "Log Borg Backup Failure";
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
          script = logScript "err" "FAILURE: System backup failed - check journalctl -u borgbackup-job-system";
        };

        systemd.services.borg-backup-log-success = {
          description = "Log Borg Backup Success";
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
          script = ''
            if [ "$MONITOR_EXIT_CODE" = "exited" ] && [ -f "/tmp/nx-backup-completed" ] && [ ! -f "/tmp/nx-backup-no-success" ]; then
              ${logScript "info" "SUCCESS: System backup completed successfully"}
              ${pkgs.coreutils}/bin/rm -f /tmp/nx-backup-completed
            fi
            ${pkgs.coreutils}/bin/rm -f /tmp/nx-backup-skipped /tmp/nx-backup-no-success
          '';
        };

        systemd.services.borgbackup-job-system = {
          unitConfig = {
            OnFailure = "borg-backup-log-failure.service";
            OnSuccess = "borg-backup-log-success.service";
            StartLimitBurst = 3;
            StartLimitIntervalSec = 3600;
          };
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5m";
            ReadWritePaths = [
              snapshotBase
              "/tmp"
            ]
            ++ lib.optional self.settings.withData "${self.settings.dataPath}/.snapshots";

            PrivateTmp = lib.mkForce false;

            ExecStopPost = "${pkgs.writeShellScript "borg-backup-stop-handler" ''
              if [ "$EXIT_CODE" = "killed" ]; then
                ${logScript "err" "FAILURE: System backup was stopped/interrupted"}
              fi
            ''}";
          };
        };

        environment.persistence."${self.persist}" = {
          directories = [
            "/root/.config/borg"
            "/root/.cache/borg"
          ];
        };

        system.activationScripts.borg-backup-setup = {
          text = ''
            ${pkgs.coreutils}/bin/mkdir -p ${snapshotBase} || true
            ${lib.optionalString self.settings.withData ''
              ${pkgs.coreutils}/bin/mkdir -p ${self.settings.dataPath}/.snapshots || true
            ''}
          '';
        };
      };

    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        lib.mkIf (!self.settings.disableOwnBackups) {
          nx.linux.server.healthchecks.servicesHealthChecks."borg-backup" = {
            trigger.service = "borgbackup-job-system.service";
            uuid = self.settings.healthcheckUUID;
            icon = "borg";
          };
        };
    };
  };
}
