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
  name = "smartd";

  group = "storage";
  input = "linux";
  namespace = "system";

  settings = {
    autodetect = true;
    devices = [ ];

    monitoring = "-a -o on -S on -W 2,45,55";

    testNotifications = false;
    pushoverNotifications = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      smartdNotifyScript = pkgs.writeShellScriptBin "smartd-notify" ''
        set -euo pipefail

        FAILURE_TYPE="''${SMARTD_FAILTYPE:-unknown}"
        DEVICE="''${SMARTD_DEVICE:-unknown}"
        MESSAGE="''${SMARTD_MESSAGE:-No message}"
        FULL_MESSAGE="''${SMARTD_FULLMESSAGE:-$MESSAGE}"
        SUBJECT="''${SMARTD_SUBJECT:-SMART error detected}"

        ${pkgs.util-linux}/bin/logger -p daemon.err -t smartd "SMART ''${FAILURE_TYPE}: ''${DEVICE} - ''${MESSAGE}"

        NOTIFY_TYPE=""
        case "$FAILURE_TYPE" in
          "EmailTest"|"EMailTest") NOTIFY_TYPE="info" ;;
          "FailedReadSmartData"|"FailedSmartOpen") NOTIFY_TYPE="failed" ;;
          "FailedHealthCheck"|"FailedSelfTest") NOTIFY_TYPE="failed" ;;
          "SelfTestExecutionStatus"|"FailedSelfTestCheck") NOTIFY_TYPE="warn" ;;
          "CurrentPendingSector"|"OfflineUncorrectableSector") NOTIFY_TYPE="warn" ;;
          "Temperature") NOTIFY_TYPE="warn" ;;
          *) NOTIFY_TYPE="failed" ;;
        esac

        USER_NOTIFY_ENABLED=${
          if self.user.isModuleEnabled "notifications.user-notify" then "true" else "false"
        }

        PUSHOVER_ENABLED=${
          if (self.isModuleEnabled "notifications.pushover") && self.settings.pushoverNotifications then
            "true"
          else
            "false"
        }

        USER_NOTIFY_MESSAGE=""
        PUSHOVER_MESSAGE=""

        if [ "$FAILURE_TYPE" = "EmailTest" ] || [ "$FAILURE_TYPE" = "EMailTest" ]; then
          USER_NOTIFY_MESSAGE="SMART Test|drive-harddisk: smartd notification system is working"
          PUSHOVER_MESSAGE="smartd notification test successful"
        else
          case "$NOTIFY_TYPE" in
            "info") ICON_NAME="drive-harddisk" ;;
            "warn") ICON_NAME="dialog-warning" ;;
            "failed") ICON_NAME="computer-fail" ;;
            *) ICON_NAME="computer-fail" ;;
          esac
          USER_NOTIFY_MESSAGE="SMART Alert (''${NOTIFY_TYPE})|$ICON_NAME: ''${DEVICE} - ''${MESSAGE}"
          PUSHOVER_MESSAGE="''${DEVICE}: ''${MESSAGE}"
        fi

        if [ "$USER_NOTIFY_ENABLED" = "true" ]; then
          ${pkgs.util-linux}/bin/logger -p user.err -t nx-user-notify "''${USER_NOTIFY_MESSAGE}"
        fi

        if [ "$PUSHOVER_ENABLED" = "true" ]; then
          ${
            (self.importFileFromOtherModuleSameInput {
              inherit args self;
              modulePath = "notifications.pushover";
            }).custom.pushoverSendScript
          }/bin/pushover-send \
            --title "SMART Disk Monitor" \
            --message "''${PUSHOVER_MESSAGE}" \
            --type "''${NOTIFY_TYPE}" || true
        fi

        echo "SMART ''${FAILURE_TYPE}: ''${DEVICE} - ''${MESSAGE}" >&2
      '';

      baseOptions = "${self.settings.monitoring} -m root";
      testOptions = if self.settings.testNotifications then " -M test" else "";

      autodetectedOptions = "${baseOptions}${testOptions}";
      monitoredOptions = "${baseOptions}${testOptions}";
    in
    {
      services.smartd = {
        enable = true;
        autodetect = self.settings.autodetect;

        notifications = {
          wall.enable = false;
          x11.enable = false;
          systembus-notify.enable = false;
          mail.enable = false;
        };

        extraOptions = [
          "-w ${smartdNotifyScript}/bin/smartd-notify"
          "-u root:root"
          "-s /var/lib/smartmontools/smartd-"
        ];

        defaults = {
          autodetected = autodetectedOptions;
          monitored = monitoredOptions;
        };

        devices = self.settings.devices;
      };

      environment.systemPackages = [
        smartdNotifyScript
        pkgs.smartmontools
      ];

      systemd.services.smartd = {
        path =
          with pkgs;
          [
            util-linux
            curl
          ]
          ++
            lib.optional (self.isModuleEnabled "notifications.pushover")
              (self.importFileFromOtherModuleSameInput {
                inherit args self;
                modulePath = "notifications.pushover";
              }).custom.pushoverSendScript;
      };

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/smartmontools"
        ];
      };
    };
}
