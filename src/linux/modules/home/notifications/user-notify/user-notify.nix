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
  name = "user-notify";

  group = "notifications";
  input = "linux";
  namespace = "home";

  settings = {
    monitoringEnabled = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      isHeadless = (self.host.settings.system.desktop or null) == null;

      iconThemeString = self.theme.icons.primary;
      iconThemePackageName = lib.head (lib.splitString "/" iconThemeString);
      iconThemePackage = lib.getAttr iconThemePackageName pkgs;
      iconThemeName = lib.head (lib.tail (lib.splitString "/" iconThemeString));
      iconThemeBasePath = "${iconThemePackage}/share/icons/${iconThemeName}";

      fallbackIconThemeString = self.theme.icons.fallback;
      fallbackIconThemePackageName = lib.head (lib.splitString "/" fallbackIconThemeString);
      fallbackIconThemePackage = lib.getAttr fallbackIconThemePackageName pkgs;
      fallbackIconThemeName = lib.head (lib.tail (lib.splitString "/" fallbackIconThemeString));
      fallbackIconThemeBasePath = "${fallbackIconThemePackage}/share/icons/${fallbackIconThemeName}";
    in
    {
      home.file.".local/bin/scripts/nx-user-notify-monitor" =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              NOTIFY_SEND="${pkgs.libnotify}/bin/notify-send"
              JOURNALCTL="${pkgs.systemd}/bin/journalctl"
              SERVICE_TAG="nx-user-notify"
              ICON_THEME_BASE="${iconThemeBasePath}"
              FALLBACK_ICON_THEME_BASE="${fallbackIconThemeBasePath}"

              CURSOR_FILE="${self.user.home}/.local/state/nx-user-notify-monitor-cursor"

              mkdir -p "$(dirname "$CURSOR_FILE")"

              resolve_icon() {
                  local icon_name="$1"

                  if [[ "$icon_name" == /* ]]; then
                      echo "$icon_name"
                      return 0
                  fi

                  for size in scalable 64x64 48x48; do
                      for iconfile in "$ICON_THEME_BASE/$size"/*/"$icon_name.svg"; do
                          if [[ -f "$iconfile" ]]; then
                              echo "$iconfile"
                              return 0
                          fi
                      done
                      for iconfile in "$FALLBACK_ICON_THEME_BASE/$size"/*/"$icon_name.svg"; do
                          if [[ -f "$iconfile" ]]; then
                              echo "$iconfile"
                              return 0
                          fi
                      done
                  done

                  return 1
              }

              notify() {
                  local urgency="''${1:-normal}"
                  local title="''${2:-System Notification}"
                  local body="''${3:-No message}"
                  local icon="''${4:-preferences-desktop-notification}"

                  local resolved_icon
                  if resolved_icon=$(resolve_icon "$icon") && [[ -r "$resolved_icon" ]]; then
                      $NOTIFY_SEND --urgency="$urgency" --icon="$resolved_icon" "$title" "$body"
                  else
                      $NOTIFY_SEND --urgency="$urgency" "$title" "$body"
                  fi
              }

              parse_message() {
                  local message="$1"
                  local priority="$2"

                  if [[ "$message" =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
                      local title_icon_part="''${BASH_REMATCH[1]}"
                      local body="''${BASH_REMATCH[2]}"

                      local title="$title_icon_part"
                      local icon=""

                      if [[ "$title_icon_part" == *"|"* ]]; then
                          title="''${title_icon_part%|*}"
                          icon="''${title_icon_part##*|}"
                      fi

                      local urgency="normal"
                      case "$priority" in
                          0|1|2|3) urgency="critical" ;;
                          *) urgency="normal" ;;
                      esac

                      notify "$urgency" "$title" "$body" "$icon"
                  else
                      local urgency="normal"
                      case "$priority" in
                          0|1|2|3) urgency="critical" ;;
                          *) urgency="normal" ;;
                      esac
                      notify "$urgency" "System Message" "$message"
                  fi
              }

              monitor_logs() {
                  $JOURNALCTL -t "$SERVICE_TAG" -f --output=json --cursor-file="$CURSOR_FILE" | while read -r line; do
                      if [[ -n "$line" ]]; then
                          local message=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.MESSAGE // empty' 2>/dev/null)
                          local priority=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.PRIORITY // "6"' 2>/dev/null)

                          if [[ -n "$message" ]]; then
                              parse_message "$message" "$priority"
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

      home.file.".local/bin/nx-user-notify-logs" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          GREEN='\033[1;32m'
          BLUE='\033[1;34m'
          RED='\033[1;31m'
          YELLOW='\033[1;33m'
          CYAN='\033[1;36m'
          NC='\033[0m'

          JOURNALCTL="${pkgs.systemd}/bin/journalctl"
          SERVICE_TAG="nx-user-notify"

          show_logs() {
              local mode="''${1:-follow}"

              echo -e "''${BLUE}=== NX USER NOTIFICATIONS LOG VIEWER ===''${NC}"
              echo -e "''${CYAN}Monitoring logger tag: $SERVICE_TAG''${NC}"
              echo -e "''${CYAN}Press Ctrl+C to exit''${NC}"
              echo

              case "$mode" in
                  "follow"|"-f")
                      echo -e "''${GREEN}=== FOLLOWING LIVE LOGS ===''${NC}"
                      $JOURNALCTL -t "$SERVICE_TAG" -f --output=short --no-hostname
                      ;;
                  "recent"|"-r")
                      echo -e "''${GREEN}=== RECENT LOGS (last 50 entries) ===''${NC}"
                      $JOURNALCTL -t "$SERVICE_TAG" --lines=50 --reverse --output=short --no-hostname
                      ;;
                  "all"|"-a")
                      echo -e "''${GREEN}=== ALL LOGS ===''${NC}"
                      $JOURNALCTL -t "$SERVICE_TAG" --output=short --no-hostname --pager-end
                      ;;
                  *)
                      echo -e "''${GREEN}=== FOLLOWING LIVE LOGS (default) ===''${NC}"
                      $JOURNALCTL -t "$SERVICE_TAG" -f --output=short --no-hostname
                      ;;
              esac
          }

          if [[ $# -eq 0 ]]; then
              show_logs "follow"
          else
              case "$1" in
                  "follow"|"-f")
                      show_logs "follow"
                      ;;
                  "recent"|"-r")
                      show_logs "recent"
                      ;;
                  "all"|"-a")
                      show_logs "all"
                      ;;
                  "help"|"-h"|"--help")
                      echo "Usage: $0 [follow|-f|recent|-r|all|-a]"
                      echo "  follow, -f  : Follow logs in real-time (default)"
                      echo "  recent, -r  : Show recent logs and exit"
                      echo "  all, -a     : Show all logs with pager"
                      echo "  help, -h    : Show this help"
                      ;;
                  *)
                      echo "Unknown option: $1"
                      echo "Use '$0 help' for usage information"
                      exit 1
                      ;;
              esac
          fi
        '';
        executable = true;
      };

      systemd.user.services.nx-user-notify-monitor =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            Unit = {
              Description = "NX User Notification Monitor";
            };
            Service = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "10";
              ExecStart = "${self.user.home}/.local/bin/scripts/nx-user-notify-monitor monitor";
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

      systemd.user.timers.nx-user-notify-monitor-startup =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            Unit = {
              Description = "Start NX User Notification Monitor";
              After = [ "graphical-session.target" ];
            };
            Timer = {
              OnActiveSec = "10s";
              Unit = "nx-user-notify-monitor-startup.service";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
            };
          };

      systemd.user.services.nx-user-notify-monitor-startup =
        lib.mkIf (self.settings.monitoringEnabled && !isHeadless)
          {
            Unit = {
              Description = "Start NX User Notification Monitor";
              After = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = "${pkgs.systemd}/bin/systemctl --user start nx-user-notify-monitor.service";
              RemainAfterExit = true;
            };
          };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+L" = {
              action = spawn-sh "${self.user.settings.terminal} -e sh -c 'nx-user-notify-logs'";
              hotkey-overlay.title = "System:User notification logs";
            };
          };
        };
      };
    };
}
