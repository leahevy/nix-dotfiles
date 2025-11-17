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

  settings = {
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
      "I/O error, dev sr[0-9]+, sector.*op.*READ.*flags.*phys_seg.*prio class"
      "Buffer I/O error on dev sr[0-9]+, logical block.*async page read"
      "blk_print_req_error: [0-9]+ callbacks suppressed"
      "buffer_io_error: [0-9]+ callbacks suppressed"
      "hrtimer: interrupt took [0-9]+ ns"
      "Failed to activate with specified passphrase\\. \\(Passphrase incorrect\\?\\)"
      "File /var/log/journal/.* corrupted or uncleanly shut down, renaming and replacing"
      "Failed to read journal file .* for rotation.*Device or resource busy"
      "usb .*device descriptor read/[0-9]+, error -[0-9]+"
      "usb.*cannot submit urb.*err = -[0-9]+"
      "uvcvideo.*UVC non compliance.*max payload transmission size.*exceeds.*ep max packet.*Using the max size"
      "Failed to get EXE, ignoring: No such process"
      "Failed to initialize pidref: No such process"
      "Couldn't find existing drive object for device.*uevent action 'change'"
      "Partitions found on device '/dev/sd[a-z]+' but couldn't read partition table signature.*No such device or address"
    ];
    desktopStringsToIgnore = [
      "Failed to associate portal window with parent window"
      "qt\\.multimedia\\.symbolsresolver: Couldn't.*pipewire"
      "qt\\.dbus\\.integration: QDBusConnection: name .* had owner"
      "qt\\.dbus\\.integration: QDBusConnection: couldn't handle call to CreateMonitor"
      "qt\\.dbus\\.integration: Could not find slot.*CreateMonitor"
      "org.kde.kdegraphics.*: .*alignment=.*"
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
      "gtk.*: assertion .* failed"
      "Realtime error: Could not get pidns for pid [0-9]+: Could not fstatat ns/pid: Not a directory"
      "unhandled exception.*in Json::Value::find.*requires objectValue or nullValue"
      "kf\\.config\\.core: couldn't lock global file"
      "kf\\.coreaddons:.*"
      "kf\\.kio\\.widgets:.*"
      "spa\\.alsa:.*snd_pcm_start.*Broken pipe"
      "spa\\.alsa:.*snd_pcm_avail.*Broken pipe"
      "spa\\.alsa:.*snd_pcm_start.*File descriptor in bad state"
      "spa\\.alsa:.*snd_pcm_drop.*No such device"
      "spa\\.alsa:.*close failed.*No such device"
      "spa\\.alsa:.*playback open failed.*Device or resource busy"
      "pw\\.node:.*suspended -> error \\(Start error: Device or resource busy\\)"
      "A backend call failed: No such method 'CreateMonitor'"
      "Failed to close session implementation: GDBus\\.Error:org\\.freedesktop\\.DBus\\.Error\\.UnknownObject"
      "libKExiv2: Cannot load metadata from file.*Error.*unknown image type"
      "qt\\.gui\\.imageio\\.jpeg: Not a JPEG file: starts with"
      ".*: Error executing command as another user: Not authorized.*gamemode.*"
      "virtual.*QDBusError.*The name is not activatable"
      "Loading IM context type .* failed"
      "kf\\.windowsystem:.*may only be used on X11"
      "QObject::disconnect: wildcard call disconnects from destroyed signal"
      "Trying to enable pgp signatures, but pgp not enabled in this build"
      "kf\\.kirigami\\.layouts:.*"
      "QPainter::.*"
      ".*: Unresolved raw mime type.*"
      "qt\\.sql\\.sqlite: Unsupported option.*"
      "qrc:/.*\\.qml:[0-9]+:[0-9]+: QML.*"
      "QQmlApplicationEngine failed to load component"
      ".*: module \"kvantum\" is not installed"
      "org\\.kde\\.pim\\..*"
      "Connecting to deprecated signal QDBusConnectionInterface::.*"
      "endResetModel called on .* without calling beginResetModel first"
      "Type .* unavailable"
      "Fatal error while loading the sidebar view qml component"
      "On Wayland, .* requires KDE Plasma's KWin compositor.*"
      "Remember requesting the interface on your desktop file: X-KDE-Wayland-Interfaces=.*"
      "Couldn't start kglobalaccel from org\\.kde\\.kglobalaccel\\.service.*"
      "kpipewire_vaapi_logging: VAAPI:.*"
      "application: invalid escaped exec argument character:.*"
    ];
    nvidiaStringsToIgnore = [
      "nvidia.*EDID checksum is invalid"
      "nvidia.*invalid EDID header"
      "nvidia-modeset:.*Unable to read EDID for display device.*"
      "nvidia: module license 'NVIDIA' taints kernel"
      "nvidia: module license taints kernel"
      "Disabling lock debugging due to kernel taint"
      "NVRM: loading NVIDIA UNIX x86_64 Kernel Module"
      "nvidia_uvm: module uses symbols.*from proprietary module nvidia, inheriting taint"
    ];
    additionalStringsToIgnore = [ ];

    baseStringsToHighlight = [ ];
    desktopStringsToHighlight = [ ];
    additionalStringsToHighlight = [ ];

    pushoverEnabled = false;
    ignoreUserServicesForPushover = true;

    baseTagsToNotIgnoreForUserServices = [ "nixos" ];
    additionalTagsToNotIgnoreForUserServices = [ ];

    pushoverRateLimit = 10;
    pushoverRateLimitUnknown = 30;
    sameMessageRateLimitMinutes = 15;
  };

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

      allStringsToHighlight =
        self.settings.baseStringsToHighlight
        ++ self.settings.additionalStringsToHighlight
        ++ (lib.optionals isDesktop self.settings.desktopStringsToHighlight);

      allTagsToNotIgnoreForUserServices =
        self.settings.baseTagsToNotIgnoreForUserServices
        ++ self.settings.additionalTagsToNotIgnoreForUserServices;

      stateDir = "/var/lib/nx-journal-watcher";
      rateLimitStateDir = "${stateDir}/rate-limits";
      cursorFile = "${stateDir}/journal-cursor";
      messageHashesFile = "${stateDir}/message-hashes";

      journalWatcherScript = pkgs.writeScriptBin "nx-journal-watcher-monitor" ''
        #!/usr/bin/env python3
        import json
        import os
        import re
        import subprocess
        import sys
        import tempfile
        import time
        from hashlib import sha256
        from pathlib import Path
        from typing import List, Optional, Dict, Any

        SERVICE_NAME = "${serviceName}"
        STATE_DIR = "${stateDir}"
        RATE_LIMIT_STATE_DIR = "${rateLimitStateDir}"
        CURSOR_FILE = "${cursorFile}"
        MESSAGE_HASHES_FILE = "${messageHashesFile}"
        RATE_LIMIT_PER_HOUR = ${toString self.settings.pushoverRateLimit}
        RATE_LIMIT_PER_HOUR_UNKNOWN = ${toString self.settings.pushoverRateLimitUnknown}
        MESSAGE_RATE_LIMIT_MINUTES = ${toString self.settings.sameMessageRateLimitMinutes}

        USER_NOTIFY_ENABLED = ${
          if (self.user.isModuleEnabled "notifications.user-notify") then "True" else "False"
        }
        PUSHOVER_ENABLED = ${
          if self.settings.pushoverEnabled && (self.isModuleEnabled "notifications.pushover") then
            "True"
          else
            "False"
        }
        IGNORE_USER_SERVICES_FOR_PUSHOVER = ${
          if self.settings.ignoreUserServicesForPushover then "True" else "False"
        }

        MAIN_USER_UID = ${toString config.users.users.${self.host.mainUser.username}.uid}

        services_to_ignore: List[str] = []
        ${lib.concatMapStringsSep "\n" (
          pattern: "services_to_ignore.append(${builtins.toJSON pattern})"
        ) allServicesToIgnore}

        tags_to_ignore: List[str] = []
        ${lib.concatMapStringsSep "\n" (
          pattern: "tags_to_ignore.append(${builtins.toJSON pattern})"
        ) allTagsToIgnore}

        strings_to_ignore: List[str] = []
        ${lib.concatMapStringsSep "\n" (
          pattern: "strings_to_ignore.append(${builtins.toJSON pattern})"
        ) allStringsToIgnore}

        strings_to_highlight: List[str] = []
        ${lib.concatMapStringsSep "\n" (
          pattern: "strings_to_highlight.append(${builtins.toJSON pattern})"
        ) allStringsToHighlight}

        tags_to_not_ignore_for_user_services: List[str] = []
        ${lib.concatMapStringsSep "\n" (
          pattern: "tags_to_not_ignore_for_user_services.append(${builtins.toJSON pattern})"
        ) allTagsToNotIgnoreForUserServices}

        services_pattern = None
        tags_pattern = None
        strings_pattern = None
        strings_highlight_pattern = None
        service_extract_pattern = None

        try:
            if services_to_ignore:
                services_pattern = re.compile("|".join(f"({re.escape(pattern)})" for pattern in services_to_ignore))
            if tags_to_ignore:
                tags_pattern = re.compile("|".join(f"({re.escape(pattern)})" for pattern in tags_to_ignore))
            if strings_to_ignore:
                strings_pattern = re.compile("|".join(f"({pattern})" for pattern in strings_to_ignore))
            if strings_to_highlight:
                strings_highlight_pattern = re.compile("|".join(f"({pattern})" for pattern in strings_to_highlight))
            service_extract_pattern = re.compile(r"^([a-zA-Z0-9_-]+\.(service|timer|socket|target|mount|path|slice|scope|device|swap|integration)):(.*)$")
        except re.error as e:
            print(f"Failed to compile regex patterns: {e}", file=sys.stderr, flush=True)
            sys.exit(1)

        def setup_directories():
            try:
                os.makedirs(STATE_DIR, exist_ok=True)
                os.makedirs(RATE_LIMIT_STATE_DIR, exist_ok=True)
            except (OSError, PermissionError) as e:
                print(f"Failed to create directories: {e}", file=sys.stderr, flush=True)
                sys.exit(1)

        def cleanup_old_rate_limits():
            current_time = int(time.time())
            cleaned_up = False

            rate_limit_path = Path(RATE_LIMIT_STATE_DIR)
            if not rate_limit_path.exists():
                return

            for file_path in rate_limit_path.iterdir():
                if file_path.is_file():
                    try:
                        stored_data = file_path.read_text().strip()
                        if ":" in stored_data:
                            _, stored_time_str = stored_data.split(":", 1)
                            stored_time = int(stored_time_str)
                            if current_time - stored_time > (2*60*60):
                                file_path.unlink()
                                cleaned_up = True
                    except (ValueError, IOError):
                        continue

            if cleaned_up:
                print("Cleaned up old rate limit files.", flush=True)

        def check_rate_limit(service_unit: str) -> bool:
            cleanup_old_rate_limits()

            service_file = re.sub(r"[^a-zA-Z0-9_-]", "_", service_unit)
            if not service_file:
                service_file = "unknown"

            rate_limit_file = Path(RATE_LIMIT_STATE_DIR) / service_file
            current_time = int(time.time())
            current_hour = current_time // 3600

            rate_limit = RATE_LIMIT_PER_HOUR_UNKNOWN if service_file == "unknown" else RATE_LIMIT_PER_HOUR

            if rate_limit_file.exists():
                try:
                    stored_data = rate_limit_file.read_text().strip()
                    stored_count, stored_time_str = stored_data.split(":", 1)
                    stored_count = int(stored_count)
                    stored_hour = int(stored_time_str) // 3600

                    if stored_hour == current_hour:
                        if stored_count >= rate_limit:
                            return False
                        else:
                            rate_limit_file.write_text(f"{stored_count + 1}:{current_time}")
                            return True
                    else:
                        rate_limit_file.write_text(f"1:{current_time}")
                        return True
                except (ValueError, IOError):
                    rate_limit_file.write_text(f"1:{current_time}")
                    return True
            else:
                rate_limit_file.write_text(f"1:{current_time}")
                return True

        def check_message_rate_limit(service_unit: str, message: str) -> bool:
            message_key = f"{service_unit}:{message}"
            message_hash = sha256(message_key.encode()).hexdigest()

            current_time = int(time.time())
            rate_limit_seconds = MESSAGE_RATE_LIMIT_MINUTES * 60

            message_hashes_path = Path(MESSAGE_HASHES_FILE)

            valid_hashes = []
            if message_hashes_path.exists():
                try:
                    for line in message_hashes_path.read_text().splitlines():
                        if ":" in line:
                            stored_hash, stored_time_str = line.split(":", 1)
                            try:
                                stored_time = int(stored_time_str)
                                if current_time - stored_time < rate_limit_seconds:
                                    valid_hashes.append(line)
                                    if stored_hash == message_hash:
                                        return False
                                else:
                                    print(f"Message rate limit expired for message: ({service_unit}) {message}", flush=True)
                            except ValueError:
                                continue
                except IOError:
                    pass

            valid_hashes.append(f"{message_hash}:{current_time}")

            try:
                message_hashes_path.write_text("\n".join(valid_hashes) + "\n")
            except IOError:
                pass

            return True

        def to_string(value, default=""):
            if isinstance(value, list):
                return str(value[0]) if value else default
            elif value is None:
                return default
            else:
                return str(value)

        def filter_message(json_data: Dict[str, Any]) -> bool:
            unit = to_string(json_data.get("_SYSTEMD_UNIT"))
            service_name = unit.replace(".service", "") if unit else ""
            tag = to_string(json_data.get("SYSLOG_IDENTIFIER"))
            message = to_string(json_data.get("MESSAGE"))
            priority = int(to_string(json_data.get("PRIORITY", "6"), "6"))

            if service_name and services_pattern and services_pattern.search(service_name):
                return False

            if tag and tags_pattern and tags_pattern.search(tag):
                return False

            if message and strings_pattern and strings_pattern.search(message):
                return False

            if priority <= 4:
                return True

            if message and strings_highlight_pattern and strings_highlight_pattern.search(message):
                return True

            return False

        def user_tag_is_not_filtered(tag: str) -> bool:
            return tag in tags_to_not_ignore_for_user_services

        def process_message(json_data: Dict[str, Any]):
            try:
                is_inner_user_service = False
                priority = to_string(json_data.get("PRIORITY", "6"), "6")
                message = to_string(json_data.get("MESSAGE"))
                unit = to_string(json_data.get("_SYSTEMD_UNIT", "unknown"), "unknown")
                tag = to_string(json_data.get("SYSLOG_IDENTIFIER", "system"), "system")

                is_user_unit = unit == f"user@{MAIN_USER_UID}.service"
                is_unknown_unit = unit == "unknown"

                if is_user_unit or is_unknown_unit:
                    match = service_extract_pattern.match(message)
                    if match:
                        is_inner_user_service = True
                        unit = match.group(1)
                        message = match.group(3).strip()

                if not message:
                    return

                if not check_message_rate_limit(unit, message):
                    print(f"Ignore notification <rate limited> ({tag}/{unit}): {message}", flush=True)
                    return

                print(f"Send notification ({tag}/{unit}): {message}", flush=True)

                priority_map = {
                    "0": "emerg", "1": "emerg", "2": "emerg",
                    "3": "failed",
                    "4": "warn"
                }
                notify_type = priority_map.get(priority, "info")

                icon_map_system = {
                    "emerg": "dialog-error",
                    "failed": "computer-fail",
                    "warn": "dialog-warning",
                    "info": "dialog-information"
                }

                icon_map_user = {
                    "emerg": "dialog-error",
                    "failed": "computer-fail",
                    "warn": "dialog-warning",
                    "info": "avatar-default"
                }

                priority_titles = {
                    "emerg": "Emergency",
                    "failed": "Failed",
                    "warn": "Warning",
                    "info": "Info"
                }

                icon = icon_map_user.get(notify_type, "avatar-default") if is_user_unit else icon_map_system.get(notify_type, "dialog-information")
                priority_title = priority_titles.get(notify_type, "Info")

                if unit == "unknown":
                    title_text_pushover = f"{priority_title} ({tag})"
                    title_text_user = f"{priority_title}|{icon}"
                    message_text_pushover = message
                    message_text_user = f"{message} <b>({tag})</b>"
                else:
                    title_text_pushover = f"{unit} ({tag})"
                    title_text_user = f"{unit}|{icon}"
                    message_text_pushover = message
                    message_text_user = f"{message} <b>({tag})</b>"

                if USER_NOTIFY_ENABLED:
                    try:
                        subprocess.run([
                            "${pkgs.util-linux}/bin/logger",
                            "-p", "user.warning",
                            "-t", "nx-user-notify",
                            f"{title_text_user}: {message_text_user}"
                        ], check=False, timeout=30)
                    except (subprocess.TimeoutExpired, OSError) as e:
                        print(f"Failed to send user notification: {e}", file=sys.stderr, flush=True)

                if PUSHOVER_ENABLED:
                    should_send_pushover = True

                    if is_user_unit and IGNORE_USER_SERVICES_FOR_PUSHOVER:
                        if is_inner_user_service or not user_tag_is_not_filtered(tag):
                            should_send_pushover = False

                    if should_send_pushover and check_rate_limit(unit):
                        try:
                            subprocess.run([
                                "${
                                  (self.importFileFromOtherModuleSameInput {
                                    inherit args self;
                                    modulePath = "notifications.pushover";
                                  }).custom.pushoverSendScript
                                }/bin/pushover-send",
                                "--title", title_text_pushover,
                                "--message", message_text_pushover,
                                "--type", notify_type
                            ], check=False, timeout=30)
                        except (subprocess.TimeoutExpired, OSError) as e:
                            print(f"Failed to send pushover notification: {e}", file=sys.stderr, flush=True)
            except Exception as e:
                print(f"Error processing message: {e}", file=sys.stderr, flush=True)

        def main():
            setup_directories()

            cmd = [
                "${pkgs.systemd}/bin/journalctl",
                "-f", "-p", "debug",
                "--output=json",
                f"--cursor-file={CURSOR_FILE}"
            ]

            print("Starting journal watcher - monitoring systemd journal for notifications", flush=True)
            try:
                with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1) as proc:
                    for line in proc.stdout:
                        line = line.strip()
                        if line:
                            try:
                                json_data = json.loads(line)
                                if filter_message(json_data):
                                    process_message(json_data)
                            except json.JSONDecodeError:
                                continue
            except KeyboardInterrupt:
                print("Journal watcher stopped.", flush=True)
            except Exception as e:
                print(f"Error: {e}", file=sys.stderr, flush=True)
                sys.exit(1)

        if __name__ == "__main__":
            main()
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
            python3
            systemd
            util-linux
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
