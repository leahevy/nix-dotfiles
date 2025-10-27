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
  name = "journal-watcher";

  group = "monitoring";
  input = "linux";
  namespace = "system";

  defaults = {
    baseServicesToIgnore = [
      "nx-journal-watcher"
      "smartd"
      "borgbackup-job-system"
      "nx-auto-upgrade"
    ];
    desktopServicesToIgnore = [ ];
    nvidiaServicesToIgnore = [ ];
    additionalServicesToIgnore = [ ];

    baseTagsToIgnore = [
      "nx-user-notify"
      "sudo"
    ];
    desktopTagsToIgnore = [ ];
    nvidiaTagsToIgnore = [ ];
    additionalTagsToIgnore = [ ];

    baseStringsToIgnore = [
      "borgbackup-job-system.service"
      "BorgBackup job system"
      "nx-auto-upgrade.service"
      "nx-auto-upgrade-delayed.service"
      "NX Auto-Upgrade"
      "USB Audio.*cannot get freq"
      "USB Audio.*cannot set freq"
      "usb.*Unable to submit urb.*at snd_usb_queue_pending_output_urbs"
      "usb.*cannot submit urb.*error.*no device"
      "\\[Firmware Bug\\]: TSC_DEADLINE disabled due to Errata"
      "x86/cpu: .*disabled by BIOS"
      "x86/cpu: .*disabled or unsupported by BIOS"
      "ENERGY_PERF_BIAS: Set to '.*', was '.*'"
      "CPU bug present and SMT on"
      "Failed to make /usr/ a mount point, ignoring"
      "PV /dev/dm-.* online, VG .* is complete"
      "VG .* finished"
      "Activation request for .* failed: The systemd unit .* could not be found"
      "Failed to get percentage from UPower"
      "ata.*supports DRM functions and may not be fully accessible"
      "sd.*No Caching mode page found"
      "sd.*Assuming drive cache: write through"
      "usb.*Warning! Unlikely big volume range.*cval->res is probably wrong"
      "usb.*current rate.*is different from the runtime rate"
      "usb.*\\[.*\\] FU \\[.*Volume\\] ch ="
      "module .*taints kernel"
      "resource: resource sanity check: requesting.*which spans more than pnp"
      "caller get_primary_reg_base.*mapping multiple BARs"
      "Ignoring duplicate name"
    ];
    desktopStringsToIgnore = [
      "qt\\.multimedia\\.symbolsresolver: Couldn't.*pipewire"
      "qt\\.dbus\\.integration: QDBusConnection: name .* had owner"
      "xdp-kde-settings: Namespace .* is not supported"
      "Choosing gtk\\.portal for .* as a last-resort fallback"
      "g_dbus_proxy_get_object_path: assertion .* failed"
      "Service file .* is not named after the D-Bus name"
      "CreateDevice failed: org\\.freedesktop\\.DBus\\.Error\\.ServiceUnknown"
      "The printer .* does not support requests with attribute set"
      "Stopping 'cups\\.service', but its triggering units are still active"
      "No limit for .* defined in policy default"
      "No JobPrivateAccess defined in policy default"
      "No JobPrivateValues defined in policy default"
      "No SubscriptionPrivateAccess defined in policy default"
      "No SubscriptionPrivateValues defined in policy default"
      "CreateProfile failed: org\\.freedesktop\\.DBus\\.Error\\.ServiceUnknown"
      "Notifier for subscription .* went away, retrying"
      "^cups\\.socket$"
      "org\\.kde\\..*: Could not load default global viewproperties"
      "org\\.kde\\..*: Unknown class .* in session saved data"
      "kf\\.kio\\.gui: Cannot read information about filesystem"
      "kf\\.kio\\.core\\.connection: Socket not connected"
      "kf\\.kio\\.core: An error occurred during write"
      "QThreadStorage: entry .* destroyed before end of thread"
      "No IM module matching GTK_IM_MODULE=.*found"
      "GTK can't handle compose tables this large"
      "Ignoring duplicate name"
      "gtk_widget_"
      "Realtime error: Could not get pidns for pid [0-9]+: Could not fstatat ns/pid: Not a directory"
      "unhandled exception.*in Json::Value::find.*requires objectValue or nullValue"
      "kf\\.config\\.core: couldn't lock global file"
      "spa\\.alsa:.*snd_pcm_start.*Broken pipe"
      "spa\\.alsa:.*snd_pcm_avail.*Broken pipe"
      "spa\\.alsa:.*snd_pcm_start.*File descriptor in bad state"
      "spa\\.alsa:.*snd_pcm_drop.*No such device"
      "spa\\.alsa:.*close failed.*No such device"
      "spa\\.alsa:.*playback open failed.*Device or resource busy"
      "pw\\.node:.*suspended -> error \\(Start error: Device or resource busy\\)"
    ];
    nvidiaStringsToIgnore = [
      "nvidia.*EDID checksum is invalid"
      "nvidia.*invalid EDID header"
      "nvidia: module license 'NVIDIA' taints kernel"
      "nvidia: module license taints kernel"
      "Disabling lock debugging due to kernel taint"
      "NVRM: loading NVIDIA UNIX x86_64 Kernel Module"
      "nvidia_uvm: module uses symbols.*from proprietary module nvidia, inheriting taint"
    ];
    additionalStringsToIgnore = [ ];

    pushoverEnabled = true;

    pushoverRateLimit = 10;
    pushoverRateLimitUnknown = 30;
    sameMessageRateLimitMinutes = 15;

    priorityLevel = "warning";
  };

  assertions = [
    {
      assertion =
        (self.user.isModuleEnabled "notifications.user-notify") || self.settings.pushoverEnabled;
      message = "At least one notification method must be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      serviceName = "nx-journal-watcher";

      isDesktop = (self.host.settings.system.desktop or null) != null;
      isNvidia = self.isModuleEnabled "graphics.nvidia-setup";

      allServicesToIgnore =
        self.settings.baseServicesToIgnore
        ++ self.settings.additionalServicesToIgnore
        ++ (lib.optionals isDesktop self.settings.desktopServicesToIgnore)
        ++ (lib.optionals isNvidia self.settings.nvidiaServicesToIgnore);

      allTagsToIgnore =
        self.settings.baseTagsToIgnore
        ++ self.settings.additionalTagsToIgnore
        ++ (lib.optionals isDesktop self.settings.desktopTagsToIgnore)
        ++ (lib.optionals isNvidia self.settings.nvidiaTagsToIgnore);

      allStringsToIgnore =
        self.settings.baseStringsToIgnore
        ++ self.settings.additionalStringsToIgnore
        ++ (lib.optionals isDesktop self.settings.desktopStringsToIgnore)
        ++ (lib.optionals isNvidia self.settings.nvidiaStringsToIgnore);

      servicesPattern =
        if allServicesToIgnore != [ ] then
          "(" + (lib.concatStringsSep "|" (map lib.escapeShellArg allServicesToIgnore)) + ")"
        else
          "^$";

      tagsPattern =
        if allTagsToIgnore != [ ] then
          "(" + (lib.concatStringsSep "|" (map lib.escapeShellArg allTagsToIgnore)) + ")"
        else
          "^$";

      stringsPattern =
        if allStringsToIgnore != [ ] then
          "(" + (lib.concatStringsSep "|" allStringsToIgnore) + ")"
        else
          "^$";

      stateDir = "/var/lib/nx-journal-watcher";
      rateLimitStateDir = "${stateDir}/rate-limits";
      cursorFile = "${stateDir}/journal-cursor";
      messageHashesFile = "${stateDir}/message-hashes";

      journalWatcherScript = pkgs.writeShellScriptBin "nx-journal-watcher-monitor" ''
        set -euo pipefail

        SERVICE_NAME="${serviceName}"
        RATE_LIMIT_STATE_DIR="${rateLimitStateDir}"
        CURSOR_FILE="${cursorFile}"
        MESSAGE_HASHES_FILE="${messageHashesFile}"
        RATE_LIMIT_PER_HOUR=${toString self.settings.pushoverRateLimit}
        RATE_LIMIT_PER_HOUR_UNKNOWN=${toString self.settings.pushoverRateLimitUnknown}
        MESSAGE_RATE_LIMIT_MINUTES=${toString self.settings.sameMessageRateLimitMinutes}

        USER_NOTIFY_ENABLED=${
          if (self.user.isModuleEnabled "notifications.user-notify") then "true" else "false"
        }
        PUSHOVER_ENABLED=${
          if self.settings.pushoverEnabled && (self.isModuleEnabled "notifications.pushover") then
            "true"
          else
            "false"
        }

        MAIN_USER_UID=${toString config.users.users.${self.host.mainUser.username}.uid}

        ${pkgs.coreutils}/bin/mkdir -p "${stateDir}"
        ${pkgs.coreutils}/bin/mkdir -p "$RATE_LIMIT_STATE_DIR"

        cleanup_old_rate_limits() {
          local current_time=$(${pkgs.coreutils}/bin/date +%s)
          local cleaned_up=0

          ${pkgs.findutils}/bin/find "$RATE_LIMIT_STATE_DIR" -type f -name "*" -mtime +0 -exec sh -c '
            for file; do
              if [[ -f "$file" ]]; then
                stored_data=$(cat "$file" 2>/dev/null || echo "")
                if [[ -n "$stored_data" ]]; then
                  stored_time=$(echo "$stored_data" | cut -d: -f2)
                  if [[ -n "$stored_time" && $(('"$current_time"' - stored_time)) -gt 7200 ]]; then
                    cleaned_up=1
                    rm -f "$file"
                  fi
                fi
              fi
            done

            if [[ $cleaned_up -eq 1 ]]; then
              echo "Cleaned up old rate limit files."
            fi
          ' sh {} +
        }

        check_rate_limit() {
          local service_unit="$1"

          cleanup_old_rate_limits

          local service_file=$(echo -n "$service_unit" | ${pkgs.coreutils}/bin/tr '/' '_' | ${pkgs.coreutils}/bin/tr -cd '[:alnum:]_-')
          if [[ -z "$service_file" ]]; then
            service_file="unknown"
          fi

          local rate_limit_file="$RATE_LIMIT_STATE_DIR/$service_file"
          local current_time=$(${pkgs.coreutils}/bin/date +%s)
          local current_hour=$((current_time / 3600))

          local rate_limit=$RATE_LIMIT_PER_HOUR
          if [[ "$service_file" == "unknown" ]]; then
            rate_limit=$RATE_LIMIT_PER_HOUR_UNKNOWN
          fi

          if [[ -f "$rate_limit_file" ]]; then
            local stored_data=$(${pkgs.coreutils}/bin/cat "$rate_limit_file")
            local stored_count=$(echo "$stored_data" | ${pkgs.coreutils}/bin/cut -d: -f1)
            local stored_hour=$(echo "$stored_data" | ${pkgs.coreutils}/bin/cut -d: -f2)
            stored_hour=$((stored_hour / 3600))

            if [[ $stored_hour -eq $current_hour ]]; then
              if [[ $stored_count -ge $rate_limit ]]; then
                return 1
              else
                echo "$((stored_count + 1)):$current_time" > "$rate_limit_file"
                return 0
              fi
            else
              echo "1:$current_time" > "$rate_limit_file"
              return 0
            fi
          else
            echo "1:$current_time" > "$rate_limit_file"
            return 0
          fi
        }

        check_message_rate_limit() {
          local service_unit="$1"
          local message="$2"

          local message_key="$service_unit:$message"
          local message_hash=$(echo -n "$message_key" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d' ' -f1)

          local current_time=$(${pkgs.coreutils}/bin/date +%s)
          local rate_limit_seconds=$((MESSAGE_RATE_LIMIT_MINUTES * 60))

          if [[ -f "$MESSAGE_HASHES_FILE" ]]; then
            local temp_file=$(${pkgs.coreutils}/bin/mktemp)

            while IFS=':' read -r stored_hash stored_time; do
              if [[ -n "$stored_hash" && -n "$stored_time" ]]; then
                if [[ $((current_time - stored_time)) -lt $rate_limit_seconds ]]; then
                  echo "$stored_hash:$stored_time" >> "$temp_file"
                else
                  echo "Message rate limit expired for message: ($service_unit) $message"
                fi
              fi
            done < "$MESSAGE_HASHES_FILE"

            ${pkgs.coreutils}/bin/mv "$temp_file" "$MESSAGE_HASHES_FILE"

            if ${pkgs.gnugrep}/bin/grep -q "^$message_hash:" "$MESSAGE_HASHES_FILE" 2>/dev/null; then
              return 1
            fi
          fi

          echo "$message_hash:$current_time" >> "$MESSAGE_HASHES_FILE"
          return 0
        }

        filter_message() {
          local json_line="$1"

          local unit=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '._SYSTEMD_UNIT // empty' 2>/dev/null || echo "")
          local service_name=""
          if [[ -n "$unit" ]]; then
            service_name=$(echo "$unit" | ${pkgs.gnused}/bin/sed 's/\.service$//')
          fi

          local tag=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '.SYSLOG_IDENTIFIER // empty' 2>/dev/null || echo "")

          local message=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '.MESSAGE // empty' 2>/dev/null || echo "")

          if [[ -n "$service_name" ]] && echo "$service_name" | ${pkgs.gnugrep}/bin/grep -qE "${servicesPattern}" 2>/dev/null; then
            return 1
          fi

          if [[ -n "$tag" ]] && echo "$tag" | ${pkgs.gnugrep}/bin/grep -qE "${tagsPattern}" 2>/dev/null; then
            return 1
          fi

          if [[ -n "$message" ]] && echo "$message" | ${pkgs.gnugrep}/bin/grep -qE "${stringsPattern}" 2>/dev/null; then
            return 1
          fi

          return 0
        }

        process_message() {
          local json_line="$1"

          local priority=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '.PRIORITY // "6"' 2>/dev/null)
          local message=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '.MESSAGE // empty' 2>/dev/null)
          local unit=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '._SYSTEMD_UNIT // "unknown"' 2>/dev/null)
          local tag=$(echo "$json_line" | ${pkgs.jq}/bin/jq -r '.SYSLOG_IDENTIFIER // "system"' 2>/dev/null)

          if [[ "$unit" == "user@$MAIN_USER_UID.service" ]]; then
            if echo "$message" | ${pkgs.gnugrep}/bin/grep -qE '^[a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap):'; then
              local extracted_service=$(echo "$message" | ${pkgs.gnused}/bin/sed -E 's/^([a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap)):.*$/\1/')
              unit="$extracted_service"
              message=$(echo "$message" | ${pkgs.gnused}/bin/sed -E 's/^[a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap): *//')
            fi
          fi

          if [[ "$unit" == "unknown" ]]; then
            if echo "$message" | ${pkgs.gnugrep}/bin/grep -qE '^[a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap):'; then
              local extracted_service=$(echo "$message" | ${pkgs.gnused}/bin/sed -E 's/^([a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap)):.*$/\1/')
              unit="$extracted_service"
              message=$(echo "$message" | ${pkgs.gnused}/bin/sed -E 's/^[a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap): *//')
            fi
          fi

          if [[ -z "$message" ]]; then
            return 0
          fi

          if ! check_message_rate_limit "$unit" "$message"; then
            echo "Ignore notification <rate limited> ($tag/$unit): $message"
            return 0
          fi

          echo "Send notification ($tag/$unit): $message"

          local notify_type="warn"
          case "$priority" in
            0|1|2) notify_type="emerg" ;;
            3) notify_type="failed" ;;
            4) notify_type="warn" ;;
            *) notify_type="info" ;;
          esac

          local title_text_pushover title_text_user
          local message_text_pushover message_text_user

          if [[ "$unit" == "unknown" ]]; then
            title_text_pushover="Journal ($tag)"
            title_text_user="Journal"
            message_text_pushover="$message"
            message_text_user="$message <b>($tag)</b>"
          else
            title_text_pushover="$unit ($tag)"
            title_text_user="$unit"
            message_text_pushover="$message"
            message_text_user="$message <b>($tag)</b>"
          fi

          if [[ "$USER_NOTIFY_ENABLED" == "true" ]]; then
            ${pkgs.util-linux}/bin/logger -p user.warning -t nx-user-notify "$title_text_user: $message_text_user"
          fi

          if [[ "$PUSHOVER_ENABLED" == "true" ]] && check_rate_limit "$unit"; then
            ${
              (self.importFileFromOtherModuleSameInput {
                inherit args self;
                modulePath = "notifications.pushover";
              }).custom.pushoverSendScript
            }/bin/pushover-send \
              --title "$title_text_pushover" \
              --message "$message_text_pushover" \
              --type "$notify_type" || true
          fi
        }

        ${pkgs.systemd}/bin/journalctl -f -p ${self.settings.priorityLevel} --output=json --cursor-file="$CURSOR_FILE" | while read -r line; do
          if [[ -n "$line" ]]; then
            if filter_message "$line"; then
              process_message "$line"
            fi
          fi
        done
      '';
    in
    {
      environment.systemPackages = [
        journalWatcherScript
      ];

      systemd.services.nx-journal-watcher = {
        description = "NX System Journal Watcher";

        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-journald.service" ];

        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = "10";
          User = "root";
          Group = "root";
          ExecStart = "${journalWatcherScript}/bin/nx-journal-watcher-monitor";
          ExecStartPre = [
            "${pkgs.coreutils}/bin/rm -f ${messageHashesFile}"
            "${pkgs.coreutils}/bin/rm -rf ${rateLimitStateDir}"
          ];

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ReadWritePaths = [ "/var/lib/nx-journal-watcher" ];

          MemoryMax = "100M";
          CPUQuota = "10%";
        };

        path =
          with pkgs;
          [
            systemd
            coreutils
            jq
            gnugrep
            gnused
            util-linux
            findutils
          ]
          ++
            lib.optionals (self.settings.pushoverEnabled && (self.isModuleEnabled "notifications.pushover"))
              [
                (self.importFileFromOtherModuleSameInput {
                  inherit args self;
                  modulePath = "notifications.pushover";
                }).custom.pushoverSendScript
              ];
      };

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/nx-journal-watcher"
        ];
      };
    };
}
