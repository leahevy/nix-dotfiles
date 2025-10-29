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

  settings = {
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
          systemctl status nx-auto-upgrade-reboot-checker.timer --no-pager --lines=3 2>/dev/null || echo "Auto-upgrade reboot checker timer not found"
          echo

          echo -e "''${GREEN}=== DELAY SERVICE STATUS ===''${NC}"
          systemctl status nx-auto-upgrade-delayed.service --no-pager --lines=3 2>/dev/null || true
          echo

          echo -e "''${GREEN}=== LAST UPGRADE STATUS ===''${NC}"
          if systemctl is-active --quiet nx-auto-upgrade.service; then
            echo -e "''${YELLOW}Auto-upgrade currently running...''${NC}"
          else
            systemctl status nx-auto-upgrade.service --no-pager --lines=5 2>/dev/null || true
          fi
          echo

          echo -e "''${GREEN}=== RECENT AUTO-UPGRADE LOGS (last 15 lines) ===''${NC}"
          nx-user-notify-logs recent 2>/dev/null | grep -i "auto-upgrade" || echo "No auto-upgrade logs found"
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

          sudo -v
          sudo systemctl start nx-auto-upgrade.service >/dev/null 2>&1 &
          echo "Auto-upgrade triggered manually"

          ${
            if isHeadless then
              ""
            else
              ''${pkgs.libnotify}/bin/notify-send --urgency="normal" "Auto-Upgrade Triggered" "Manual auto-upgrade triggered" --icon=automated-tasks''
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
