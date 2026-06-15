args@{
  lib,
  pkgs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "api-keys";
  group = "security";
  input = "linux";
  description = "API key expiry tracking and rotation notifications";

  options = {
    keys = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            displayName = lib.mkOption {
              type = lib.types.str;
              description = "Human-readable name shown in notifications for this API key.";
            };
            lifetimeDays = lib.mkOption {
              type = lib.types.ints.positive;
              default = 365;
              description = "Expected lifetime in days before the API key must be rotated.";
            };
            notifyThresholdDays = lib.mkOption {
              type = lib.types.ints.positive;
              default = 30;
              description = "Number of days before expiry at which notifications begin.";
            };
            secretName = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Name of the SOPS secret entry holding this API key.";
            };
            healthchecksUUID = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Healthchecks.io UUID for the API key expiry timed check.";
            };
            healthchecksWarnDays = lib.mkOption {
              type = lib.types.ints.positive;
              default = 5;
              description = "Number of days before expiry at which the healthchecks.io timed check starts failing.";
            };
            rotatedAt = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  year = lib.mkOption {
                    type = lib.types.int;
                    default = 1970;
                    description = "Year the key was last rotated.";
                  };
                  month = lib.mkOption {
                    type = lib.types.ints.between 1 12;
                    default = 1;
                    description = "Month the key was last rotated.";
                  };
                  day = lib.mkOption {
                    type = lib.types.ints.between 1 31;
                    default = 1;
                    description = "Day the key was last rotated.";
                  };
                };
              };
              default = { };
              description = "Date the API key was last rotated. Defaults to 1970-01-01 as an unconfigured sentinel.";
            };
          };
        }
      );
      default = { };
      description = "API keys tracked for expiry notifications, keyed by service identifier.";
    };
  };

  module = {
    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        let
          mkTimedCheck =
            keyId: keyCfg:
            let
              rotationDate = "${toString keyCfg.rotatedAt.year}-${
                lib.fixedWidthString 2 "0" (toString keyCfg.rotatedAt.month)
              }-${lib.fixedWidthString 2 "0" (toString keyCfg.rotatedAt.day)}";
            in
            lib.nameValuePair "api-key-expiry-${keyId}" {
              schedule = "*-*-* 10:30:00";
              randomDelaySec = 900;
              uuid = keyCfg.healthchecksUUID;
              icon = "key";
              checks = {
                "10 - Key expiry" = ''
                  ROTATED_AT=${lib.escapeShellArg rotationDate}
                  LIFETIME_DAYS=${toString keyCfg.lifetimeDays}
                  WARN_DAYS=${toString keyCfg.healthchecksWarnDays}
                  DISPLAY_NAME=${lib.escapeShellArg keyCfg.displayName}
                  ROTATED_EPOCH=$(${pkgs.coreutils}/bin/date -d "$ROTATED_AT" +%s 2>/dev/null || true)
                  if [[ -z "$ROTATED_EPOCH" ]]; then
                    printf 'invalid rotatedAt date: %s\n' "$ROTATED_AT" >&3
                    exit 1
                  fi
                  EXPIRY_EPOCH=$((ROTATED_EPOCH + LIFETIME_DAYS * 86400))
                  NOW_EPOCH=$(${pkgs.coreutils}/bin/date +%s)
                  DAYS_LEFT=$(((EXPIRY_EPOCH - NOW_EPOCH) / 86400))
                  EXPIRY_DATE=$(${pkgs.coreutils}/bin/date -d "@$EXPIRY_EPOCH" +%Y-%m-%d)
                  if [[ "$DAYS_LEFT" -lt 0 ]]; then
                    DAYS_OVERDUE=$((0 - DAYS_LEFT))
                    printf '%s: expired %d days ago (expiry: %s)\n' "$DISPLAY_NAME" "$DAYS_OVERDUE" "$EXPIRY_DATE" >&3
                    exit 1
                  elif [[ "$DAYS_LEFT" -le "$WARN_DAYS" ]]; then
                    printf '%s: expires in %d days (expiry: %s)\n' "$DISPLAY_NAME" "$DAYS_LEFT" "$EXPIRY_DATE" >&3
                    exit 1
                  fi
                  printf '%s: %d days remaining (expiry: %s)\n' "$DISPLAY_NAME" "$DAYS_LEFT" "$EXPIRY_DATE" >&3
                '';
              };
            };
        in
        {
          nx.linux.server.healthchecks.timedHealthChecks =
            lib.mapAttrs' mkTimedCheck config.nx.linux.security.api-keys.keys;
        };
    };

    linux.system =
      { config, keys, ... }:
      {
        assertions =
          lib.mapAttrsToList (keyId: keyCfg: {
            assertion = keyCfg.rotatedAt.year != 1970;
            message = "linux.security.api-keys: key '${keyId}' (${keyCfg.displayName}) rotatedAt is still at the 1970 default. Set nx.linux.security.api-keys.keys.\"${keyId}\".rotatedAt in your profile to the date the key was last rotated!";
          }) keys
          ++ lib.mapAttrsToList (keyId: keyCfg: {
            assertion = keyCfg.lifetimeDays >= 10;
            message = "linux.security.api-keys: key '${keyId}' (${keyCfg.displayName}) lifetimeDays (${toString keyCfg.lifetimeDays}) must be at least 10 to allow a valid notifyThresholdDays!";
          }) keys
          ++ lib.mapAttrsToList (keyId: keyCfg: {
            assertion = keyCfg.notifyThresholdDays >= 5;
            message = "linux.security.api-keys: key '${keyId}' (${keyCfg.displayName}) notifyThresholdDays (${toString keyCfg.notifyThresholdDays}) must be at least 5!";
          }) keys
          ++ lib.mapAttrsToList (keyId: keyCfg: {
            assertion = keyCfg.notifyThresholdDays * 2 <= keyCfg.lifetimeDays;
            message = "linux.security.api-keys: key '${keyId}' (${keyCfg.displayName}) notifyThresholdDays (${toString keyCfg.notifyThresholdDays}) must not exceed 50% of lifetimeDays (${toString keyCfg.lifetimeDays})!";
          }) keys;

        environment.persistence."${self.persist}" = lib.mkIf (keys != { }) {
          directories = [ "/var/lib/nx-api-keys" ];
        };

        systemd.tmpfiles.settings."nx-api-keys" = lib.mkIf (keys != { }) (
          {
            "/var/lib/nx-api-keys".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
          }
          // lib.optionalAttrs (helpers.resolveFromHost self [ "impermanence" ] false) {
            "${self.persist}/var/lib/nx-api-keys".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
          }
        );

        systemd.services = lib.mapAttrs' (
          keyId: keyCfg:
          let
            rotationDate = "${toString keyCfg.rotatedAt.year}-${
              lib.fixedWidthString 2 "0" (toString keyCfg.rotatedAt.month)
            }-${lib.fixedWidthString 2 "0" (toString keyCfg.rotatedAt.day)}";
            serviceName = "api-key-expiry-notify-${keyId}";
            markerFile = "/var/lib/nx-api-keys/${keyId}-last-notified";
            secretInfo = lib.optionalString (keyCfg.secretName != null) "\n\nSecret: ${keyCfg.secretName}";
            pushoverEnabled = config.nx.linux.notifications.pushover.enable;
          in
          lib.nameValuePair serviceName {
            description = "${keyCfg.displayName} API key expiry check";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              ExecStart = pkgs.writeShellScript serviceName ''
                set -euo pipefail

                ROTATED_AT=${lib.escapeShellArg rotationDate}
                LIFETIME_DAYS=${toString keyCfg.lifetimeDays}
                THRESHOLD_DAYS=${toString keyCfg.notifyThresholdDays}
                MARKER_FILE=${lib.escapeShellArg markerFile}
                ROTATED_EPOCH=$(${pkgs.coreutils}/bin/date -d "$ROTATED_AT" +%s 2>/dev/null || true)

                if [[ -z "$ROTATED_EPOCH" ]]; then
                  printf 'Invalid rotatedAt date for ${keyId}: %s\n' "$ROTATED_AT" >&2
                  exit 1
                fi

                EXPIRY_EPOCH=$((ROTATED_EPOCH + LIFETIME_DAYS * 86400))
                NOW_EPOCH=$(${pkgs.coreutils}/bin/date +%s)
                DAYS_LEFT=$(((EXPIRY_EPOCH - NOW_EPOCH) / 86400))
                EXPIRY_DATE=$(${pkgs.coreutils}/bin/date -d "@$EXPIRY_EPOCH" +%Y-%m-%d)

                if [[ "$DAYS_LEFT" -gt "$THRESHOLD_DAYS" ]]; then
                  exit 0
                fi

                if [[ -f "$MARKER_FILE" ]] && [[ "$(${pkgs.coreutils}/bin/cat "$MARKER_FILE" 2>/dev/null || true)" == "$EXPIRY_DATE" ]]; then
                  exit 0
                fi

                if [[ "$DAYS_LEFT" -lt 0 ]]; then
                  DAYS_OVERDUE=$((0 - DAYS_LEFT))
                  printf 'WARN: ${keyCfg.displayName} API key expired %d days ago (expiry: %s), rotate it!\n' "$DAYS_OVERDUE" "$EXPIRY_DATE" >&2
                  ${lib.optionalString pushoverEnabled (
                    config.nx.linux.notifications.pushover.send {
                      title = keyCfg.displayName;
                      message = "${keyCfg.displayName} API key expired $DAYS_OVERDUE days ago, rotate it!${secretInfo}";
                      shellVars = true;
                      type = "warn";
                    }
                  )}
                else
                  printf 'WARN: ${keyCfg.displayName} API key expires in %d days (expiry: %s), rotate it soon!\n' "$DAYS_LEFT" "$EXPIRY_DATE" >&2
                  ${lib.optionalString pushoverEnabled (
                    config.nx.linux.notifications.pushover.send {
                      title = keyCfg.displayName;
                      message = "${keyCfg.displayName} API key expires in $DAYS_LEFT days, rotate it soon!${secretInfo}";
                      shellVars = true;
                      type = "warn";
                    }
                  )}
                fi

                printf '%s\n' "$EXPIRY_DATE" > "$MARKER_FILE"
              '';
            };
          }
        ) keys;

        systemd.timers = lib.mapAttrs' (
          keyId: keyCfg:
          let
            serviceName = "api-key-expiry-notify-${keyId}";
          in
          lib.nameValuePair serviceName {
            description = "Daily ${keyCfg.displayName} API key expiry check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 10:00:00";
              Persistent = true;
              RandomizedDelaySec = 900;
            };
          }
        ) keys;
      };
  };
}
