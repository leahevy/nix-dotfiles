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
  name = "auto-upgrades";

  group = "system";
  input = "linux";
  namespace = "home";

  defaults = {
    monitoringEnabled = true;
    terminal = "ghostty";
  };

  assertions = [
    {
      assertion = self.isLinux -> (self.linux.host.isModuleEnabled "system.auto-upgrades");
      message = "auto-upgrades home module requires linux system.auto-upgrades system module to be enabled";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      isHeadless = (self.host.settings.system.desktop or null) == null;

    in
    {
      home.file.".local/bin/scripts/auto-upgrade-monitor" =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              NOTIFY_SEND="${pkgs.libnotify}/bin/notify-send"
              JOURNALCTL="${pkgs.systemd}/bin/journalctl"
              SERVICE_TAG="nx-auto-upgrade"

              CURSOR_FILE="${self.user.home}/.local/state/auto-upgrade-monitor-cursor"

              mkdir -p "$(dirname "$CURSOR_FILE")"

              notify() {
                  local urgency="''${1:-normal}"
                  local summary="''${2:-No summary}"
                  local body="''${3:-No body}"

                  $NOTIFY_SEND --urgency="$urgency" "$summary" "$body"
              }

              monitor_logs() {
                  $JOURNALCTL -t "$SERVICE_TAG" -f --output=json --cursor-file="$CURSOR_FILE" | while read -r line; do
                      if [[ -n "$line" ]]; then
                          local message=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.MESSAGE // empty' 2>/dev/null)

                          if [[ -n "$message" ]]; then
                              case "$message" in
                                  *"STARTED:"*)
                                      notify "normal" "Auto-Upgrade Started" "System auto-upgrade is beginning..."
                                      ;;
                                  *"SUCCESS:"*)
                                      notify "normal" "Auto-Upgrade Complete" "System auto-upgrade completed successfully"
                                      ;;
                                  *"FAILURE:"*)
                                      notify "critical" "Auto-Upgrade Failed" "''${message#*FAILURE: }"
                                      ;;
                                  *)
                                      notify "normal" "Auto-Upgrade Update" "$message"
                                      ;;
                              esac
                          fi
                      fi
                  done
              }

              case "''${1:-monitor}" in
                  "monitor")
                      monitor_logs
                      ;;
                  *)
                      echo "Usage: $0 {monitor}"
                      exit 1
                      ;;
              esac
            '';
            executable = true;
          };

      home.file.".local/bin/auto-upgrade-status" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          GREEN='\033[1;32m'
          BLUE='\033[1;34m'
          RED='\033[1;31m'
          YELLOW='\033[1;33m'
          NC='\033[0m'

          echo -e "''${BLUE}=== NX AUTO-UPGRADE STATUS ===''${NC}"
          echo

          echo -e "''${GREEN}=== TIMER STATUS ===''${NC}"
          systemctl status nx-auto-upgrade-notify.timer --no-pager --lines=3 2>/dev/null || echo "Auto-upgrade notify timer not found"
          echo
          systemctl status nx-auto-upgrade.timer --no-pager --lines=3 2>/dev/null || echo "Auto-upgrade timer not found"
          echo
          systemctl status nx-auto-upgrade-reboot-checker.timer --no-pager --lines=3 2>/dev/null || echo "Auto-upgrade reboot checker timer not found"
          echo

          echo -e "''${GREEN}=== LAST UPGRADE STATUS ===''${NC}"
          if systemctl is-active --quiet nx-auto-upgrade.service; then
            echo -e "''${YELLOW}Auto-upgrade currently running...''${NC}"
          else
            systemctl status nx-auto-upgrade.service --no-pager --lines=5 2>/dev/null || true
          fi
          echo

          echo -e "''${GREEN}=== RECENT AUTO-UPGRADE LOGS (last 15 lines) ===''${NC}"
          journalctl -t nx-auto-upgrade --no-pager --lines=15 --reverse 2>/dev/null || echo "No auto-upgrade logs found"
          echo

          if ! systemctl is-active --quiet nx-auto-upgrade.service && systemctl is-failed --quiet nx-auto-upgrade.service; then
            echo -e "''${RED}=== AUTO-UPGRADE SERVICE FAILURE LOGS ===''${NC}"
            journalctl -u nx-auto-upgrade.service --no-pager --lines=15 --reverse 2>/dev/null
            echo
          fi

          echo
          echo -e "''${BLUE}Press any key to exit...''${NC}"
          read -n 1
        '';
        executable = true;
      };

      home.file.".local/bin/auto-upgrade-trigger-manually" = {
        text = ''
                    #!/usr/bin/env bash
                    set -euo pipefail

                    if [[ $EUID -eq 0 ]]; then
                      echo "Must be run as user!"
                      exit 1
                    fi

                    if systemctl is-active --quiet nx-auto-upgrade.service; then
                      echo "Error: Auto-upgrade is already running!"
                      exit 1
                    fi

                    echo "Starting auto-upgrade manually..."
                    sudo systemctl start nx-auto-upgrade.service >/dev/null 2>&1 &

          ${
            if isHeadless then
              ""
            else
              ''${pkgs.libnotify}/bin/notify-send --urgency="normal" "Auto-Upgrade Triggered" "Manual auto-upgrade triggered"''
          }
        '';
        executable = true;
      };

      home.file.".local/bin/auto-upgrade-logs" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [[ $# -eq 0 ]]; then
            journalctl -t nx-auto-upgrade -f --output=short
          else
            case "$1" in
              "follow"|"-f")
                journalctl -t nx-auto-upgrade -f --output=short
                ;;
              "recent"|"-r")
                journalctl -t nx-auto-upgrade --lines=50 --reverse --output=short
                ;;
              *)
                echo "Usage: $0 [follow|-f|recent|-r]"
                echo "  follow, -f  : Follow logs in real-time"
                echo "  recent, -r  : Show recent logs"
                echo "  (no args)   : Follow logs in real-time (default)"
                exit 1
                ;;
            esac
          fi
        '';
        executable = true;
      };

      systemd.user.services.auto-upgrade-monitor =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            Unit = {
              Description = "Auto-Upgrade Log Monitor";
            };
            Service = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "10";
              ExecStart = "${self.user.home}/.local/bin/scripts/auto-upgrade-monitor monitor";
              Environment = [
                "PATH=${
                  lib.makeBinPath [
                    pkgs.bash
                    pkgs.coreutils
                    pkgs.libnotify
                    pkgs.systemd
                    pkgs.jq
                  ]
                }"
              ];
            };
          };

      systemd.user.timers.auto-upgrade-monitor-startup =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            Unit = {
              Description = "Start Auto-Upgrade Monitor";
              After = [ "graphical-session.target" ];
            };
            Timer = {
              OnActiveSec = "10s";
              Unit = "auto-upgrade-monitor-startup.service";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
          };

      systemd.user.services.auto-upgrade-monitor-startup =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            Unit = {
              Description = "Start Auto-Upgrade Monitor";
              After = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${pkgs.systemd}/bin/systemctl --user start auto-upgrade-monitor.service";
              RemainAfterExit = true;
            };
          };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+G" = {
              action = spawn-sh "${self.settings.terminal} -e sh -c 'auto-upgrade-status'";
              hotkey-overlay.title = "System:Auto-upgrade status";
            };
          };
        };
      };
    };
}
