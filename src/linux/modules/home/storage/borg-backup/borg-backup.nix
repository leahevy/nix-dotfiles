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
  name = "borg-backup";

  group = "storage";
  input = "linux";
  namespace = "home";

  settings = {
    terminal = "ghostty";
  };

  assertions = [
    {
      assertion = self.isLinux -> (self.linux.isModuleEnabled "storage.borg-backup");
      message = "borg-backup home module requires linux storage.borg-backup system module to be enabled";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      isHeadless = (self.host.settings.system.desktop or null) == null;
      systemBorgConfig = self.host.getModuleConfig "storage.borg-backup";
      repoUrl = "ssh://${systemBorgConfig.repository.user}@${systemBorgConfig.repository.server}:${toString systemBorgConfig.repository.port}${systemBorgConfig.repository.path}";
      hostname = self.host.hostname;

      borgEnvSetup = ''
        export BORG_RSH="ssh -i /run/secrets/${hostname}-borg-ssh-key -o UserKnownHostsFile=/run/secrets/${hostname}-borg-known-hosts"
        export BORG_PASSPHRASE="$(cat /run/secrets/${hostname}-borg-passphrase)"
        export BORG_REPO="${repoUrl}"
      '';

      translatePath = ''
        translate_path() {
          local path="$1"
          if [[ "$path" =~ ^/persist(/.*) ]]; then
            echo "persist/.snapshots/persist''${BASH_REMATCH[1]}"
          elif [[ "$path" == "/persist" ]]; then
            echo "persist/.snapshots/persist"
          elif [[ "$path" =~ ^/data(/.*) ]]; then
            echo "data/.snapshots/data''${BASH_REMATCH[1]}"
          elif [[ "$path" == "/data" ]]; then
            echo "data/.snapshots/data"
          elif [[ "$path" =~ ^/nix(/.*) ]]; then
            echo "persist/.snapshots/nix''${BASH_REMATCH[1]}"
          elif [[ "$path" == "/nix" ]]; then
            echo "persist/.snapshots/nix"
          elif [[ "$path" =~ ^/boot(/.*) ]]; then
            echo "boot''${BASH_REMATCH[1]}"
          elif [[ "$path" == "/boot" ]]; then
            echo "boot"
          else
            echo "$path"
          fi
        }

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
    in
    {

      home.file.".local/bin/borg-backup-status" = {
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

      home.file.".local/bin/borg-backup-list" = {
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

      home.file.".local/bin/borg-backup-restore" = {
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

      home.file.".local/bin/borg-backup-search" = {
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

      home.file.".local/bin/borg-backup-find-archives" = {
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

      home.file.".local/bin/borg-backup-run" = {
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

      home.file.".local/bin/borg-backup-trigger-manually" = {
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
                    sudo systemctl start borgbackup-job-system.service
                    echo "Success: Backup triggered manually"

          ${
            if isHeadless then
              ""
            else
              ''${pkgs.libnotify}/bin/notify-send --urgency="normal" "Backup Triggered" "Manual backup triggered - will start in 2 minutes" --icon=archive''
          }
        '';
        executable = true;
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+B" = {
              action = spawn-sh "${self.settings.terminal} -e sh -c 'borg-backup-status'";
              hotkey-overlay.title = "System:Backup status";
            };
          };
        };
      };
    };
}
