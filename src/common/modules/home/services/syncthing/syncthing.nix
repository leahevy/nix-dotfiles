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
  name = "syncthing";

  group = "services";
  input = "common";
  namespace = "home";

  defaults = {
    syncName = "";
    syncID = "";
    syncIPAddress = "";
    syncPort = 22000;
    trayEnabled = false;
    guiPort = 8384;
    versioningKeepNumbers = 10;
    shares = { };
    announceEnabled = false;
    monitoringEnabled = true;
    terminal = "ghostty";
  };

  assertions = [
    {
      assertion = self.settings.syncName != null && self.settings.syncName != "";
      message = "syncName is not set!";
    }
    {
      assertion = self.settings.syncID != null && self.settings.syncID != "";
      message = "syncID is not set!";
    }
    {
      assertion = self.settings.syncIPAddress != null && self.settings.syncIPAddress != "";
      message = "syncIPAddress is not set!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      sops.secrets."${self.host.hostname}-syncthing-key" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "syncthing.key";
      };

      sops.secrets."${self.host.hostname}-syncthing-cert" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "syncthing.cert";
      };

      sops.secrets."${self.host.hostname}-syncthing-password" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "syncthing.password";
      };

      systemd.user.services.syncthing = lib.mkMerge [
        (lib.mkIf (self.linux.isModuleEnabled "storage.luks-data-drive") {
          Unit = {
            After = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
            Requires = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
          };
        })
        {
          Unit = {
            After = lib.mkAfter [ "sops-nix.service" ];
            Requires = lib.mkAfter [ "sops-nix.service" ];
          };
        }
      ];

      services.syncthing = {
        enable = true;
        overrideDevices = true;
        overrideFolders = true;
        guiAddress = "127.0.0.1:${builtins.toString self.settings.guiPort}";
        passwordFile = config.sops.secrets."${self.host.hostname}-syncthing-password".path;
        extraOptions = [ "--no-default-folder" ];
        tray = self.settings.trayEnabled;
        key = "${config.sops.secrets."${self.host.hostname}-syncthing-key".path}";
        cert = "${config.sops.secrets."${self.host.hostname}-syncthing-cert".path}";
        settings = {
          options.urAccepted = -1;
          options.relaysEnabled = false;
          options.localAnnounceEnabled = self.settings.announceEnabled;
          devices = {
            "${self.settings.syncName}" = {
              addresses = [
                "tcp://${self.settings.syncIPAddress}:${builtins.toString self.settings.syncPort}"
              ];
              id = self.settings.syncID;
            };
          };
          folders = builtins.mapAttrs (folderId: localPath: {
            path = "${self.user.home}/${localPath}";
            devices = [ self.settings.syncName ];
            versioning = {
              type = "simple";
              params.keep = "${builtins.toString self.settings.versioningKeepNumbers}";
            };
          }) self.settings.shares;
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".local/state/syncthing"
        ];
        files = lib.mkIf self.settings.trayEnabled [
          ".config/syncthingtray.ini"
        ];
      };

      home.file.".local/bin/syncthing-status" = {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          GREEN='\033[1;32m'
          BLUE='\033[1;34m'
          RED='\033[1;31m'
          YELLOW='\033[1;33m'
          NC='\033[0m'

          echo -e "''${BLUE}=== SYNCTHING STATUS ===''${NC}"
          echo

          echo -e "''${GREEN}=== SERVICE STATUS ===''${NC}"
          systemctl --user status syncthing.service --no-pager --lines=0 2>/dev/null || echo "Syncthing service not found"
          echo

          echo -e "''${GREEN}=== GUI ACCESS ===''${NC}"
          if systemctl --user is-active --quiet syncthing.service; then
            echo -e "''${GREEN}Syncthing is running - GUI available at: http://127.0.0.1:${builtins.toString self.settings.guiPort}''${NC}"
          else
            echo -e "''${RED}Syncthing is not running''${NC}"
          fi
          echo

          echo -e "''${GREEN}=== RECENT SYNCTHING LOGS (last 5 lines) ===''${NC}"
          journalctl --user -u syncthing.service --no-pager --lines=5 --reverse 2>/dev/null || echo "No syncthing logs found"
          echo

          if systemctl --user is-failed --quiet syncthing.service; then
            echo -e "''${RED}=== SERVICE FAILURE LOGS ===''${NC}"
            journalctl --user -u syncthing.service --no-pager --lines=15 --reverse 2>/dev/null
            echo
          fi

          echo -e "''${GREEN}=== MONITORING SERVICES ===''${NC}"
          systemctl --user status syncthing-monitor-status.service --no-pager --lines=2 2>/dev/null || echo "Monitor status service not found"
          echo
          systemctl --user status syncthing-monitor-logs.service --no-pager --lines=2 2>/dev/null || echo "Monitor logs service not found"
          echo

          echo
          echo -e "''${BLUE}Press any key to exit...''${NC}"
          read -n 1
        '';
        executable = true;
      };

      home.file.".local/bin/scripts/syncthing-monitor" = lib.mkIf self.settings.monitoringEnabled {
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          NOTIFY_SEND="${pkgs.libnotify}/bin/notify-send"
          JOURNALCTL="${pkgs.systemd}/bin/journalctl"
          SERVICE_NAME="syncthing.service"

          STATE_FILE="$HOME/.local/state/syncthing-monitor-state"
          mkdir -p "$(dirname "$STATE_FILE")"

          notify() {
              local urgency="''${1:-normal}"
              local summary="''${2:-No summary}"
              local body="''${3:-No body}"

              $NOTIFY_SEND --urgency="$urgency" --icon=dirsync "$summary" "$body"
          }

          check_service_status() {
              local current_state=""
              if [[ -f "$STATE_FILE" ]]; then
                  current_state="$(cat "$STATE_FILE" 2>/dev/null || echo "")"
              fi

              if systemctl --user is-active "$SERVICE_NAME" >/dev/null 2>&1; then
                  if [[ ! -f "$STATE_FILE" ]] || [[ "$current_state" != "running" ]]; then
                      echo "running" > "$STATE_FILE"
                      notify "normal" "Syncthing Started" "Syncthing service is now running. Open with: http://127.0.0.1:${builtins.toString self.settings.guiPort}"
                  fi
              else
                  if [[ -f "$STATE_FILE" ]] && [[ "$current_state" == "running" ]]; then
                      echo "stopped" > "$STATE_FILE"
                      notify "critical" "Syncthing Stopped" "Syncthing service has stopped unexpectedly"
                  fi
              fi
          }

          monitor_logs() {
              local cursor_file="$HOME/.local/state/syncthing-monitor-cursor"
              local seen_messages_file="$HOME/.local/state/syncthing-monitor-seen"
              local cursor_arg=""

              if [[ -f "$cursor_file" ]]; then
                  cursor_arg="--cursor-file=$cursor_file"
              fi

              $JOURNALCTL --user -u "$SERVICE_NAME" -f --output=json $cursor_arg --cursor-file="$cursor_file" | while read -r line; do
                  if [[ -n "$line" ]]; then
                      local message=$(echo "$line" | ${pkgs.jq}/bin/jq -r '.MESSAGE // empty' 2>/dev/null)

                      if [[ -n "$message" ]]; then
                          local message_hash=$(echo "$message" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)
                          local should_notify=true

                          if [[ -f "$seen_messages_file" ]] && ${pkgs.gnugrep}/bin/grep -q "^$message_hash$" "$seen_messages_file"; then
                              should_notify=false
                          fi

                          if [[ "$should_notify" == "true" ]]; then
                              echo "$message_hash" >> "$seen_messages_file"

                              case "$message" in
                                  *"ERROR"*|*"error"*|*"Error"*)
                                      notify "critical" "Syncthing Error" "$message"
                                      ;;
                                  *"WARNING"*|*"warning"*|*"Warning"*)
                                      notify "normal" "Syncthing Warning" "$message"
                                      ;;
                                  *"Connection to"*"failed"*|*"connection failed"*|*"Connection lost"*)
                                      notify "normal" "Syncthing Connection Issue" "$message"
                                      ;;
                                  *"Folder"*"error"*|*"folder"*"error"*|*"sync error"*|*"synchronization error"*)
                                      notify "critical" "Syncthing Sync Error" "$message"
                                      ;;
                                  *"Device"*"disconnected"*|*"device"*"disconnected"*)
                                      notify "normal" "Syncthing Device Disconnected" "$message"
                                      ;;
                              esac
                          fi
                      fi
                  fi
              done
          }

          case "''${1:-monitor}" in
              "status")
                  check_service_status
                  ;;
              "logs")
                  monitor_logs
                  ;;
              "monitor")
                  while true; do
                      check_service_status
                      sleep 10
                  done
                  ;;
              *)
                  echo "Usage: $0 {status|logs|monitor}"
                  exit 1
                  ;;
          esac
        '';
        executable = true;
      };

      systemd.user.services.syncthing-monitor-status = lib.mkIf self.settings.monitoringEnabled {
        Unit = {
          Description = "Syncthing Status Monitor";
          After = [ "syncthing.service" ];
          Wants = [ "syncthing.service" ];
        };
        Service = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "10";
          ExecStart = "${config.home.homeDirectory}/.local/bin/scripts/syncthing-monitor monitor";
          Environment = [
            "PATH=${
              lib.makeBinPath [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.libnotify
                pkgs.systemd
              ]
            }"
          ];
        };
      };

      systemd.user.services.syncthing-monitor-logs = lib.mkIf self.settings.monitoringEnabled {
        Unit = {
          Description = "Syncthing Log Monitor";
          After = [ "syncthing.service" ];
          Wants = [ "syncthing.service" ];
        };
        Service = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "10";
          ExecStart = "${config.home.homeDirectory}/.local/bin/scripts/syncthing-monitor logs";
          Environment = [
            "PATH=${
              lib.makeBinPath [
                pkgs.bash
                pkgs.coreutils
                pkgs.curl
                pkgs.libnotify
                pkgs.systemd
              ]
            }"
          ];
        };
      };

      systemd.user.timers.syncthing-monitor-startup = lib.mkIf self.settings.monitoringEnabled {
        Unit = {
          Description = "Start Syncthing Monitoring Services";
          After = [ "graphical-session.target" ];
        };
        Timer = {
          OnActiveSec = "10s";
          Unit = "syncthing-monitor-startup.service";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      systemd.user.services.syncthing-monitor-startup = lib.mkIf self.settings.monitoringEnabled {
        Unit = {
          Description = "Start Syncthing Monitoring Services";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = [
            "${pkgs.systemd}/bin/systemctl --user start syncthing-monitor-status.service"
            "${pkgs.systemd}/bin/systemctl --user start syncthing-monitor-logs.service"
          ];
          RemainAfterExit = true;
        };
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+S" = {
              action = spawn-sh "${self.settings.terminal} -e sh -c 'syncthing-status'";
              hotkey-overlay.title = "System:Syncthing status";
            };
          };
        };
      };
    };
}
