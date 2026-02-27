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

  settings = {
    trayEnabled = false;
    guiPort = 8384;
    versioningKeepNumbers = 10;
    announceEnabled = false;
    monitoringEnabled = true;
    folderBasedMonitoringEnabled = true;
    folderBasedMonitoringDeviceInterval = 15;
    folderBasedMonitoringDeviceSyncInterval = 10;
    folderBasedMonitoringFolderInterval = 30;
    folderBasedMonitoringInitialDelay = 45;
    enableHotfixForUpgradeToSyncthing2_0 = false;
    devices = [ ];
  };

  assertions = [
    {
      assertion = self.settings.devices != null && self.settings.devices != [ ];
      message = "devices list is empty! At least one device must be configured.";
    }
    {
      assertion = builtins.all (d: d.name != null && d.name != "") self.settings.devices;
      message = "All devices must have a name set!";
    }
    {
      assertion = builtins.all (d: d.id != null && d.id != "") self.settings.devices;
      message = "All devices must have an id set!";
    }
    {
      assertion = builtins.all (d: d.ipAddress != null && d.ipAddress != "") self.settings.devices;
      message = "All devices must have an ipAddress set!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      devicesAttr = builtins.listToAttrs (
        map (d: {
          name = d.name;
          value = {
            addresses = [ "tcp://${d.ipAddress}:${builtins.toString (d.port or 22000)}" ];
            id = d.id;
          }
          // lib.optionalAttrs (d.untrusted or false) {
            untrusted = true;
          };
        }) self.settings.devices
      );

      allShares = builtins.foldl' (
        acc: device:
        builtins.foldl' (
          innerAcc: folderId:
          let
            shareConfig = device.shares.${folderId};
            localPath = if builtins.isString shareConfig then shareConfig else shareConfig.path;
            existing = innerAcc.${folderId} or null;
            isUntrusted = device.untrusted or false;
            deviceEntry =
              if isUntrusted then
                {
                  name = device.name;
                  encryptionPasswordFile = config.sops.secrets."syncthing-${device.name}-encryption-password".path;
                }
              else
                device.name;
          in
          innerAcc
          // {
            ${folderId} =
              if existing == null then
                {
                  path = "${self.user.home}/${localPath}";
                  devices = [ deviceEntry ];
                }
              else
                {
                  path = existing.path;
                  devices = existing.devices ++ [ deviceEntry ];
                };
          }
        ) acc (builtins.attrNames (device.shares or { }))
      ) { } self.settings.devices;

      foldersAttr = builtins.mapAttrs (folderId: folderData: {
        path = folderData.path;
        devices = folderData.devices;
        versioning = {
          type = "simple";
          params.keep = "${builtins.toString self.settings.versioningKeepNumbers}";
        };
      }) allShares;

      untrustedDevices = builtins.filter (d: d.untrusted or false) self.settings.devices;
    in
    {
      sops.secrets = {
        "${self.host.hostname}-syncthing-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing.key";
        };

        "${self.host.hostname}-syncthing-cert" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing.cert";
        };

        "${self.host.hostname}-syncthing-password" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing.password";
        };

        "${self.host.hostname}-syncthing-api-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing.api-key";
        };
      }
      // builtins.listToAttrs (
        map (d: {
          name = "syncthing-${d.name}-encryption-password";
          value = {
            format = "binary";
            sopsFile = self.profile.secretsPath "syncthing-${d.name}-encryption.password";
          };
        }) untrustedDevices
      );

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

      # Hotfix for Syncthing v1.x -> v2.0 database migration race condition
      # Source: https://github.com/NixOS/nixpkgs/issues/465573
      # Credit: @altano for the original fix
      systemd.user.services.syncthing-init = lib.mkIf self.settings.enableHotfixForUpgradeToSyncthing2_0 {
        Service = {
          ExecStartPre = pkgs.writeShellScript "wait-for-syncthing-api" ''
            echo "Waiting for Syncthing API to complete database migration..."

            CONFIG_PATH=""
            if [[ -f "''${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml" ]]; then
              CONFIG_PATH="''${XDG_STATE_HOME:-$HOME/.local/state}/syncthing/config.xml"
            elif [[ -f "$HOME/.config/syncthing/config.xml" ]]; then
              CONFIG_PATH="$HOME/.config/syncthing/config.xml"
            else
              echo "ERROR: Could not find syncthing config.xml"
              exit 1
            fi

            API_KEY=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "$CONFIG_PATH")

            for i in {1..900}; do
              response=$(${pkgs.curl}/bin/curl -sf -H "X-API-Key: $API_KEY" http://127.0.0.1:${builtins.toString self.settings.guiPort}/rest/system/config 2>&1 || true)

              if echo "$response" | ${pkgs.jq}/bin/jq -e . > /dev/null 2>&1; then
                echo "Syncthing API is ready (migration complete)"
                exit 0
              fi

              if echo "$response" | ${pkgs.gnugrep}/bin/grep -q "Database migration in progress"; then
                echo "Database migration still in progress... (waited $i seconds)"
              fi

              ${pkgs.coreutils}/bin/sleep 1
            done
            echo "ERROR: Syncthing API did not become available within 15 minutes"
            exit 1
          '';
        };
      };

      services.syncthing = {
        enable = true;
        overrideDevices = true;
        overrideFolders = true;
        guiAddress = "127.0.0.1:${builtins.toString self.settings.guiPort}";
        passwordFile = config.sops.secrets."${self.host.hostname}-syncthing-password".path;
        extraOptions = [ ];
        tray.enable = self.settings.trayEnabled;
        key = "${config.sops.secrets."${self.host.hostname}-syncthing-key".path}";
        cert = "${config.sops.secrets."${self.host.hostname}-syncthing-cert".path}";
        settings = {
          options.urAccepted = -1;
          options.relaysEnabled = false;
          options.natEnabled = false;
          options.localAnnounceEnabled = self.settings.announceEnabled;
          devices = devicesAttr;
          folders = foldersAttr;
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

              echo "Sending notification: [$urgency] $summary - $body"
              $NOTIFY_SEND --urgency="$urgency" --icon=syncthing "$summary" "$body"
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
                                  *"NAT-PMP"*|*"UPnP"*)
                                      # Ignore NAT-PMP and UPnP messages
                                      ;;
                                  *"INF Lost device connection"*|*"INF Connection closed"*)
                                      # Ignore lost device connection info messages
                                      ;;
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

      home.file.".local/bin/scripts/syncthing-folder-based-monitor" =
        lib.mkIf self.settings.folderBasedMonitoringEnabled
          {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              API_KEY_FILE="${config.sops.secrets."${self.host.hostname}-syncthing-api-key".path}"
              SYNCTHING_GUI_PORT="${builtins.toString self.settings.guiPort}"
              DEVICE_INTERVAL="${builtins.toString self.settings.folderBasedMonitoringDeviceInterval}"
              DEVICE_SYNC_INTERVAL="${builtins.toString self.settings.folderBasedMonitoringDeviceSyncInterval}"
              FOLDER_INTERVAL="${builtins.toString self.settings.folderBasedMonitoringFolderInterval}"
              INITIAL_DELAY="${builtins.toString self.settings.folderBasedMonitoringInitialDelay}"

              declare -A DEVICE_NAMES
              ${lib.concatStringsSep "\n" (
                map (d: "DEVICE_NAMES[\"${d.id}\"]=\"${d.name}\"") self.settings.devices
              )}

              STATE_DIR="$HOME/.local/state/syncthing-folder-monitor"
              DEVICE_STATE_FILE="$STATE_DIR/device-states"
              DEVICE_SYNC_STATE_FILE="$STATE_DIR/device-sync-states"
              FOLDER_STATE_FILE="$STATE_DIR/folder-states"
              FIRST_CHECK_FILE="$STATE_DIR/first-check-done"

              mkdir -p "$STATE_DIR"

              if [[ ! -f "$API_KEY_FILE" ]] || [[ ! -r "$API_KEY_FILE" ]] || [[ ! -s "$API_KEY_FILE" ]]; then
                  exit 0
              fi

              get_device_display_name() {
                  local device_id="$1"
                  if [[ -n "''${DEVICE_NAMES[$device_id]:-}" ]]; then
                      echo "''${DEVICE_NAMES[$device_id]}"
                  else
                      echo "$device_id"
                  fi
              }

              get_folder_display_string() {
                  local folder_id="$1"
                  local folder_label="$2"
                  local folder_path="$3"

                  if [[ "$folder_id" == "$folder_label" ]]; then
                      echo "<b>$folder_label</b> <i>[$folder_path]</i>"
                  else
                      echo "<b>$folder_label</b> <i>[$folder_id at $folder_path]</i>"
                  fi
              }

              check_folder_device_sync_status() {
                  local folder_id="$1"
                  local syncing_devices=()
                  local device_count=0

                  FOLDER_CONFIG_FILE="$TEMP_DIR/folder_config_$folder_id"
                  if ! curl -s -H @"$HEADER_FILE" "http://127.0.0.1:$SYNCTHING_GUI_PORT/rest/config/folders/$folder_id" > "$FOLDER_CONFIG_FILE"; then
                      echo ""
                      return
                  fi

                  local folder_devices
                  folder_devices=$(jq -r '.devices[].deviceID' "$FOLDER_CONFIG_FILE" 2>/dev/null)

                  while read -r device_id; do
                      [[ -z "$device_id" ]] && continue

                      if [[ -f "$DEVICE_STATE_FILE" ]] && ! grep -q "^$device_id=true$" "$DEVICE_STATE_FILE"; then
                          continue
                      fi

                      device_count=$((device_count + 1))

                      COMPLETION_FILE="$TEMP_DIR/completion_''${device_id}_''${folder_id}"
                      if curl -s -H @"$HEADER_FILE" "http://127.0.0.1:$SYNCTHING_GUI_PORT/rest/db/completion?device=$device_id&folder=$folder_id" > "$COMPLETION_FILE"; then
                          completion=$(jq -r '.completion' "$COMPLETION_FILE" 2>/dev/null || echo "100")
                          if [[ "$completion" != "100" ]]; then
                              device_display_name=$(get_device_display_name "$device_id")
                              syncing_devices+=("$device_display_name")
                          fi
                      fi
                  done <<< "$folder_devices"

                  if [[ ''${#syncing_devices[@]} -gt 0 ]]; then
                      if [[ ''${#syncing_devices[@]} -eq 1 ]]; then
                          echo " (still syncing to ''${syncing_devices[0]})"
                      else
                          echo " (still syncing to ''${#syncing_devices[@]}/''${device_count} devices)"
                      fi
                  else
                      echo " (Up to Date)"
                  fi
              }

              notify() {
                  local urgency="$1"
                  local summary="$2"
                  local body="$3"
                  local icon="$4"
                  icon="syncthing"

                  echo "Sending notification: [$urgency] $summary - $body"
                  notify-send --urgency="$urgency" --icon="$icon" "$summary" "$body"
              }

              sleep "$INITIAL_DELAY"

              is_first_check=false
              if [[ ! -f "$FIRST_CHECK_FILE" ]]; then
                  is_first_check=true
              fi

              check_devices() {
                  declare -A prev_device_states
                  if [[ -f "$DEVICE_STATE_FILE" ]]; then
                      while IFS='=' read -r device_id connected; do
                          [[ -n "$device_id" && -n "$connected" ]] && prev_device_states["$device_id"]="$connected"
                      done < "$DEVICE_STATE_FILE"
                  fi

                  CONNECTIONS_FILE="$TEMP_DIR/connections"
                  if curl -s -H @"$HEADER_FILE" "http://127.0.0.1:$SYNCTHING_GUI_PORT/rest/system/connections" > "$CONNECTIONS_FILE"; then
                      declare -A current_device_states
                      > "$DEVICE_STATE_FILE"

                      if command -v jq >/dev/null 2>&1; then
                          while IFS='=' read -r device_id connected; do
                              [[ -z "$device_id" || -z "$connected" ]] && continue

                              current_device_states["$device_id"]="$connected"
                              echo "$device_id=$connected" >> "$DEVICE_STATE_FILE"

                              if [[ "$is_first_check" == "true" ]]; then
                                  if [[ "$connected" == "false" ]]; then
                                      device_display_name=$(get_device_display_name "$device_id")
                                      notify "normal" "Syncthing: Device" "Disconnected: <b>$device_display_name</b>" "computer-fail"
                                  fi
                              else
                                  prev_connected="''${prev_device_states[$device_id]:-unknown}"

                                  if [[ "$prev_connected" != "$connected" ]]; then
                                      device_display_name=$(get_device_display_name "$device_id")
                                      case "$connected" in
                                          "true")
                                              if [[ "$prev_connected" == "false" ]]; then
                                                  notify "normal" "Syncthing: Device" "Connected: <b>$device_display_name</b>" "checkmark"
                                              fi
                                              ;;
                                          "false")
                                              if [[ "$prev_connected" == "true" ]]; then
                                                  notify "normal" "Syncthing: Device" "Disconnected: <b>$device_display_name</b>" "computer-fail"
                                              fi
                                              ;;
                                      esac
                                  fi
                              fi
                          done < <(jq -r '.connections | to_entries[] | "\(.key)=\(.value.connected)"' "$CONNECTIONS_FILE" 2>/dev/null || true)
                      fi
                  fi
              }

              check_device_sync() {
                  declare -A prev_device_sync_states
                  declare -A prev_device_state_hashes
                  if [[ -f "$DEVICE_SYNC_STATE_FILE" ]]; then
                      while IFS='=' read -r device_id status_and_hash; do
                          if [[ -n "$device_id" && -n "$status_and_hash" ]]; then
                              if [[ "$status_and_hash" == *"|"* ]]; then
                                  sync_status="''${status_and_hash%|*}"
                                  state_hash="''${status_and_hash#*|}"
                                  prev_device_sync_states["$device_id"]="$sync_status"
                                  prev_device_state_hashes["$device_id"]="$state_hash"
                              else
                                  prev_device_sync_states["$device_id"]="$status_and_hash"
                                  prev_device_state_hashes["$device_id"]="0"
                              fi
                          fi
                      done < "$DEVICE_SYNC_STATE_FILE"
                  fi

                  declare -A current_device_sync_states
                  > "$DEVICE_SYNC_STATE_FILE"

                  if command -v jq >/dev/null 2>&1; then
                      if [[ -f "$DEVICE_STATE_FILE" ]]; then
                          while IFS='=' read -r device_id connected; do
                              [[ -z "$device_id" || "$connected" != "true" ]] && continue

                              COMPLETION_FILE="$TEMP_DIR/completion_$device_id"
                              if curl -s -H @"$HEADER_FILE" "http://127.0.0.1:$SYNCTHING_GUI_PORT/rest/db/completion?device=$device_id" > "$COMPLETION_FILE"; then
                                  completion=$(jq -r '.completion' "$COMPLETION_FILE" 2>/dev/null || echo "100")
                                  state_hash=$(jq -S '.' "$COMPLETION_FILE" 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "0")

                                  if [[ "$completion" == "100" ]]; then
                                      sync_status="idle"
                                  else
                                      sync_status="syncing"
                                  fi

                                  current_device_sync_states["$device_id"]="$sync_status"
                                  echo "$device_id=$sync_status|$state_hash" >> "$DEVICE_SYNC_STATE_FILE"

                                  if [[ "$is_first_check" == "true" ]]; then
                                      if [[ "$sync_status" == "syncing" ]]; then
                                          device_display_name=$(get_device_display_name "$device_id")
                                          notify "normal" "Syncthing: Device Sync" "Currently syncing: <b>$device_display_name</b>" "folder-sync"
                                      fi
                                  else
                                      prev_sync_status="''${prev_device_sync_states[$device_id]:-unknown}"

                                      if [[ "$prev_sync_status" != "$sync_status" ]]; then
                                          device_display_name=$(get_device_display_name "$device_id")
                                          case "$sync_status" in
                                              "syncing")
                                                  if [[ "$prev_sync_status" == "idle" || "$prev_sync_status" == "unknown" ]]; then
                                                      notify "normal" "Syncthing: Device Sync" "Started syncing: <b>$device_display_name</b>" "folder-sync"
                                                  fi
                                                  ;;
                                              "idle")
                                                  if [[ "$prev_sync_status" == "syncing" ]]; then
                                                      notify "normal" "Syncthing: Device Sync" "Completed syncing: <b>$device_display_name</b> (Up to Date)" "checkmark"
                                                  fi
                                                  ;;
                                          esac
                                      else
                                          prev_hash="''${prev_device_state_hashes[$device_id]:-0}"
                                          if [[ "$prev_hash" != "0" && "$state_hash" != "$prev_hash" && "$sync_status" == "idle" ]]; then
                                              device_display_name=$(get_device_display_name "$device_id")
                                              notify "normal" "Syncthing: Device Sync" "Updated: <b>$device_display_name</b> (Up to Date)" "checkmark"
                                          fi
                                      fi
                                  fi
                              fi
                          done < "$DEVICE_STATE_FILE"
                      fi
                  fi
              }

              check_folders() {
                  declare -A prev_folder_states
                  declare -A prev_folder_sequences
                  if [[ -f "$FOLDER_STATE_FILE" ]]; then
                      while IFS='=' read -r folder_id state_and_seq; do
                          if [[ -n "$folder_id" && -n "$state_and_seq" ]]; then
                              if [[ "$state_and_seq" == *"|"* ]]; then
                                  state="''${state_and_seq%|*}"
                                  sequence="''${state_and_seq#*|}"
                                  prev_folder_states["$folder_id"]="$state"
                                  prev_folder_sequences["$folder_id"]="$sequence"
                              else
                                  prev_folder_states["$folder_id"]="$state_and_seq"
                                  prev_folder_sequences["$folder_id"]="0"
                              fi
                          fi
                      done < "$FOLDER_STATE_FILE"
                  fi

                  FOLDERS_FILE="$TEMP_DIR/folders"
                  if curl -s -H @"$HEADER_FILE" "http://127.0.0.1:$SYNCTHING_GUI_PORT/rest/config/folders" > "$FOLDERS_FILE"; then
                      declare -A current_folder_states
                      > "$FOLDER_STATE_FILE"

                      if command -v jq >/dev/null 2>&1; then
                          while IFS='|' read -r folder_id folder_label folder_path; do
                              [[ -z "$folder_id" ]] && continue

                              FOLDER_STATUS_FILE="$TEMP_DIR/folder_$folder_id"
                              if curl -s -H @"$HEADER_FILE" "http://127.0.0.1:$SYNCTHING_GUI_PORT/rest/db/status?folder=$folder_id" > "$FOLDER_STATUS_FILE"; then

                                  state=$(jq -r '.state' "$FOLDER_STATUS_FILE" 2>/dev/null || echo "unknown")
                                  sequence=$(jq -r '.sequence' "$FOLDER_STATUS_FILE" 2>/dev/null || echo "0")
                                  pull_errors=$(jq -r '.pullErrors' "$FOLDER_STATUS_FILE" 2>/dev/null || echo "0")
                                  need_items=$(jq -r '.needTotalItems' "$FOLDER_STATUS_FILE" 2>/dev/null || echo "0")

                                  effective_state="$state"
                                  if [[ "$pull_errors" != "0" ]] && [[ "$pull_errors" != "null" ]] && [[ "$pull_errors" -gt 0 ]]; then
                                      effective_state="error"
                                  elif [[ "$need_items" != "0" ]] && [[ "$need_items" != "null" ]] && [[ "$need_items" -gt 0 ]] && [[ "$state" == "idle" ]]; then
                                      effective_state="out-of-sync"
                                  fi

                                  current_folder_states["$folder_id"]="$effective_state"
                                  echo "$folder_id=$effective_state|$sequence" >> "$FOLDER_STATE_FILE"

                                  folder_display=$(get_folder_display_string "$folder_id" "$folder_label" "$folder_path")

                                  if [[ "$is_first_check" == "true" ]]; then
                                      if [[ "$effective_state" != "idle" ]]; then
                                          case "$effective_state" in
                                              "scanning"|"sync-preparing"|"syncing")
                                                  notify "normal" "Syncthing: Folder Sync" "Currently syncing: $folder_display" "folder-sync"
                                                  ;;
                                              "error")
                                                  notify "critical" "Syncthing: Folder Error" "$folder_display has $pull_errors pull errors - manual intervention needed" "dialog-error"
                                                  ;;
                                              "out-of-sync")
                                                  notify "normal" "Syncthing: Folder Sync" "Out of sync: $folder_display has $need_items items pending" "folder-sync"
                                                  ;;
                                          esac
                                      fi
                                  else
                                      prev_state="''${prev_folder_states[$folder_id]:-unknown}"

                                      if [[ "$prev_state" != "$effective_state" ]]; then
                                          case "$effective_state" in
                                              "scanning"|"sync-preparing"|"syncing")
                                                  if [[ "$prev_state" == "idle" || "$prev_state" == "unknown" ]]; then
                                                      notify "normal" "Syncthing: Folder Sync" "Started: $folder_display" "folder-sync"
                                                  fi
                                                  ;;
                                              "idle")
                                                  if [[ "$prev_state" == "scanning" || "$prev_state" == "sync-preparing" || "$prev_state" == "syncing" ]]; then
                                                      sync_status=$(check_folder_device_sync_status "$folder_id")
                                                      notify "normal" "Syncthing: Folder Sync" "Completed: $folder_display$sync_status" "checkmark"
                                                  fi
                                                  ;;
                                              "error")
                                                  notify "critical" "Syncthing: Folder Error" "$folder_display has $pull_errors pull errors - manual intervention needed" "dialog-error"
                                                  ;;
                                              "out-of-sync")
                                                  notify "normal" "Syncthing: Folder Sync" "Out of sync: $folder_display has $need_items items pending" "folder-sync"
                                                  ;;
                                          esac
                                      else
                                          prev_sequence="''${prev_folder_sequences[$folder_id]:-0}"
                                          if [[ "$prev_sequence" != "0" && "$sequence" != "$prev_sequence" && "$effective_state" == "idle" ]]; then
                                              sync_status=$(check_folder_device_sync_status "$folder_id")
                                              notify "normal" "Syncthing: Folder Sync" "Updated: $folder_display$sync_status" "checkmark"
                                          fi
                                      fi
                                  fi
                              fi
                          done < <(jq -r '.[] | "\(.id)|\(.label // .id)|\(.path)"' "$FOLDERS_FILE" 2>/dev/null || true)
                      fi
                  fi
              }

              LAST_DEVICE_CHECK=0
              LAST_DEVICE_SYNC_CHECK=0
              LAST_FOLDER_CHECK=0
              BASE_INTERVAL=$(( DEVICE_INTERVAL < DEVICE_SYNC_INTERVAL ? (DEVICE_INTERVAL < FOLDER_INTERVAL ? DEVICE_INTERVAL : FOLDER_INTERVAL) : (DEVICE_SYNC_INTERVAL < FOLDER_INTERVAL ? DEVICE_SYNC_INTERVAL : FOLDER_INTERVAL) ))

              while true; do
                  TEMP_DIR=$(mktemp -d)
                  chmod 700 "$TEMP_DIR"

                  HEADER_FILE="$TEMP_DIR/headers"
                  {
                      echo "X-API-Key: $(cat "$API_KEY_FILE")"
                      echo "Content-Type: application/json"
                  } > "$HEADER_FILE"
                  chmod 600 "$HEADER_FILE"

                  cleanup() {
                      rm -rf "$TEMP_DIR"
                  }
                  trap cleanup EXIT

                  check_devices
                  LAST_DEVICE_CHECK=$(date +%s)

                  cleanup
                  trap - EXIT

                  if [[ -f "$DEVICE_STATE_FILE" ]] && [[ -s "$DEVICE_STATE_FILE" ]]; then
                      break
                  fi

                  sleep 5
              done

              while true; do
                  CURRENT_TIME=$(date +%s)

                  TEMP_DIR=$(mktemp -d)
                  chmod 700 "$TEMP_DIR"

                  HEADER_FILE="$TEMP_DIR/headers"
                  {
                      echo "X-API-Key: $(cat "$API_KEY_FILE")"
                      echo "Content-Type: application/json"
                  } > "$HEADER_FILE"
                  chmod 600 "$HEADER_FILE"

                  cleanup() {
                      rm -rf "$TEMP_DIR"
                  }
                  trap cleanup EXIT

                  if (( CURRENT_TIME - LAST_DEVICE_CHECK >= DEVICE_INTERVAL )); then
                      check_devices
                      LAST_DEVICE_CHECK=$CURRENT_TIME
                  fi

                  if (( CURRENT_TIME - LAST_DEVICE_SYNC_CHECK >= DEVICE_SYNC_INTERVAL )); then
                      check_device_sync
                      LAST_DEVICE_SYNC_CHECK=$CURRENT_TIME
                  fi

                  if (( CURRENT_TIME - LAST_FOLDER_CHECK >= FOLDER_INTERVAL )); then
                      check_folders
                      LAST_FOLDER_CHECK=$CURRENT_TIME
                  fi

                  if [[ "$is_first_check" == "true" ]]; then
                      touch "$FIRST_CHECK_FILE"
                      is_first_check=false
                  fi

                  cleanup
                  trap - EXIT

                  sleep "$BASE_INTERVAL"
              done
            '';
            executable = true;
          };

      systemd.user.services.syncthing-folder-based-monitor =
        lib.mkIf self.settings.folderBasedMonitoringEnabled
          {
            Unit = {
              Description = "Syncthing Folder-Based Monitor";
              After = [
                "syncthing.service"
                "sops-nix.service"
              ];
              Wants = [ "syncthing.service" ];
              Requires = [ "sops-nix.service" ];
            };
            Service = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = "30";
              ExecStart = "${config.home.homeDirectory}/.local/bin/scripts/syncthing-folder-based-monitor";
              Environment = [
                "PATH=${
                  lib.makeBinPath [
                    pkgs.bash
                    pkgs.coreutils
                    pkgs.curl
                    pkgs.jq
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
          ]
          ++ lib.optionals self.settings.folderBasedMonitoringEnabled [
            "${pkgs.systemd}/bin/systemctl --user start syncthing-folder-based-monitor.service"
          ];
          RemainAfterExit = true;
        };
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+S" = {
              action = spawn-sh "${self.user.settings.terminal} -e sh -c 'syncthing-status'";
              hotkey-overlay.title = "System:Syncthing status";
            };
          };
        };
      };
    };
}
