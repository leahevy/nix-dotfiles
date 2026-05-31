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
  name = "healthchecks";
  description = "Healthchecks.io monitoring integration";

  group = "server";
  input = "linux";

  options = {
    pingBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://hc-ping.com";
      description = "Base URL for the healthchecks.io ping endpoint.";
    };

    enableRegularHealthCheck = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable the regular health check timer; null auto-enables in server and managed deployment modes.";
    };

    healthName = lib.mkOption {
      type = lib.types.str;
      default = "health-regular";
      description = "Endpoint name suffix for the regular check, prefixed with the hostname.";
    };

    healthInterval = lib.mkOption {
      type = lib.types.str;
      default = "60s";
      description = "Interval between regular health check runs, passed to systemd OnUnitInactiveSec/OnBootSec.";
    };

    healthRandomDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "RandomizedDelaySec for the regular health check timer in seconds.";
    };

    regularHealthChecks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional checks for the regular health check, as attrset of description to bash expression.";
    };

    requireServicesUp = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Service units that must be active, each generating a named check in the regular health check.";
    };

    memoryFreeThresholdPct = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Minimum combined free percentage of MemFree+SwapFree relative to MemTotal before the memory check fails.";
    };

    enableDailyHealthCheck = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable the daily health check timer. It is auto-enabled in server and managed deployment modes.";
    };

    dailyName = lib.mkOption {
      type = lib.types.str;
      default = "health-daily";
      description = "Endpoint name suffix for the daily check, prefixed with the hostname.";
    };

    dailyHealthCheckSchedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 02:30:00";
      description = "OnCalendar schedule for the daily health check.";
    };

    dailyRandomDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 900;
      description = "RandomizedDelaySec for the daily health check timer in seconds.";
    };

    dailyHealthChecks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional checks for the daily health check, as attrset of description to bash expression.";
    };

    checkDiskUsage = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check that all local filesystems have at least diskFreeThresholdPct percent free.";
    };

    diskFreeThresholdPct = lib.mkOption {
      type = lib.types.int;
      default = 20;
      description = "Minimum free disk percentage per filesystem before the disk check fails.";
    };

    checkCertExpiry = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Check TLS certificates in /var/lib/acme for upcoming expiry.";
    };

    certExpiryWarnDays = lib.mkOption {
      type = lib.types.int;
      default = 14;
      description = "Days before certificate expiry at which to start reporting failure.";
    };

    checkSmartDisk = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run SMART health checks on mounted SATA and NVMe block devices.";
    };

    serviceTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 1200;
      description = "TimeoutStartSec for all generated health check services in seconds.";
    };

    healthchecksBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://healthchecks.io";
      description = "Base URL of the healthchecks.io web UI, used to build dashboard links. Override for self-hosted instances.";
    };

    projectUUID = lib.mkOption {
      type = lib.types.str;
      description = "Healthchecks.io project UUID (not the ping key) used to build the dashboard URL included in notifications.";
    };

    servicesHealthChecks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            trigger = lib.mkOption {
              type = lib.types.submodule {
                options.runsAfter = lib.mkOption {
                  type = lib.types.str;
                  description = "Service unit this check is ordered after.";
                };
              };
              description = "Trigger configuration.";
            };
            check = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  checkScript = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Bash expression whose exit code determines pass or fail.";
                  };
                };
              };
              default = { };
              description = "Optional additional check scripts.";
            };
            includeLogs = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Append the trigger unit's last journal logs to the ping body.";
            };
          };
        }
      );
      default = { };
      description = "Health checks triggered by other systemd units, keyed by endpoint name suffix.";
    };
  };

  module = {
    ifEnabled.linux.security.letsencrypt.enabled = config: {
      nx.linux.server.healthchecks.checkCertExpiry = lib.mkDefault true;
    };

    linux.system =
      {
        config,
        pingBaseUrl,
        enableRegularHealthCheck,
        healthName,
        healthInterval,
        healthRandomDelaySec,
        regularHealthChecks,
        requireServicesUp,
        memoryFreeThresholdPct,
        enableDailyHealthCheck,
        dailyName,
        dailyHealthCheckSchedule,
        dailyRandomDelaySec,
        dailyHealthChecks,
        checkDiskUsage,
        diskFreeThresholdPct,
        checkCertExpiry,
        certExpiryWarnDays,
        checkSmartDisk,
        servicesHealthChecks,
        serviceTimeoutSec,
        healthchecksBaseUrl,
        projectUUID,
        ...
      }:
      let
        hostname = self.host.hostname;
        mainUser = self.host.mainUser.username;
        mainUserUid = toString config.users.users.${self.host.mainUser.username}.uid;
        deploymentMode = config.nx.global.deploymentMode;
        secretPath = config.sops.secrets."${hostname}-healthchecks-uuid".path;
        projectUrl = "${healthchecksBaseUrl}/projects/${projectUUID}/checks/";

        effectiveRegular =
          if enableRegularHealthCheck != null then
            enableRegularHealthCheck
          else
            deploymentMode == "server" || deploymentMode == "managed";

        effectiveDaily =
          if enableDailyHealthCheck != null then
            enableDailyHealthCheck
          else
            deploymentMode == "server" || deploymentMode == "managed";

        hasServiceChecks = servicesHealthChecks != { };

        regularEndpointName = "${hostname}-${healthName}";
        dailyEndpointName = "${hostname}-${dailyName}";

        sanitizeName =
          key:
          lib.replaceStrings
            [
              " "
              "_"
              "."
              "/"
              ","
              ":"
              ";"
            ]
            [
              "-"
              "-"
              "-"
              "-"
              "-"
              "-"
              "-"
            ]
            (lib.toLower key);

        makeCheckScript =
          desc: cmd:
          pkgs.writeShellScript "nx-hc-check-${sanitizeName desc}" ''
            set -e
            ${cmd}
          '';

        makeServiceActiveCheck = svc: ''
          _elapsed=0
          while true; do
            _state=$(${pkgs.systemd}/bin/systemctl is-active ${lib.escapeShellArg svc} 2>/dev/null || true)
            if [[ "$_state" == "active" ]]; then
              exit 0
            fi
            if [[ "$_state" != "activating" && "$_state" != "deactivating" && "$_state" != "reloading" ]]; then
              exit 1
            fi
            if [[ $_elapsed -ge 10 ]]; then
              exit 1
            fi
            ${pkgs.coreutils}/bin/sleep 1
            _elapsed=$((_elapsed + 1))
          done
        '';

        memoryCheckExpr = ''
          ${pkgs.gawk}/bin/awk '
            /MemTotal/{t=$2} /MemFree/{f=$2} /SwapTotal/{st=$2} /SwapFree/{sf=$2}
            END{
              mem_used=(t>0) ? (t-f)*100/t : 0
              if (st > 0) {
                swap_used=(st-sf)*100/st
                combined_free=(f+sf)*100/(t+st)
                printf "%.0f%% mem used, %.0f%% swap used\n", mem_used, swap_used > "/dev/fd/3"
              } else {
                combined_free=(t>0) ? f*100/t : 100
                printf "%.0f%% mem used\n", mem_used > "/dev/fd/3"
              }
              exit (combined_free < ${toString memoryFreeThresholdPct})
            }
          ' /proc/meminfo
        '';

        diskUsageExpr = ''
          FAILURES=()
          while IFS= read -r line; do
            pct=$(printf '%s' "$line" | ${pkgs.gawk}/bin/awk '{gsub(/%/,"",$1); print $1}')
            mnt=$(printf '%s' "$line" | ${pkgs.gawk}/bin/awk '{print $2}')
            [[ "$pct" =~ ^[0-9]+$ ]] || continue
            free_pct=$((100 - pct))
            printf '%s: %d%% free\n' "$mnt" "$free_pct" >&3
            if [[ $free_pct -lt ${toString diskFreeThresholdPct} ]]; then
              FAILURES+=("$mnt: $free_pct% free")
            fi
          done < <(${pkgs.coreutils}/bin/df -l -x tmpfs -x devtmpfs --output=pcent,target 2>/dev/null | tail -n +2)
          if [[ ''${#FAILURES[@]} -gt 0 ]]; then
            echo "Low disk space:"
            printf '  %s\n' "''${FAILURES[@]}"
            exit 1
          fi
        '';

        certExpiryExpr = ''
          FAILURES=()
          for certfile in /var/lib/acme/*/cert.pem; do
            [[ -f "$certfile" ]] || continue
            domain=$(${pkgs.coreutils}/bin/basename \
              "$(${pkgs.coreutils}/bin/dirname "$certfile")")
            enddate=$(${pkgs.openssl}/bin/openssl x509 -enddate -noout \
              -in "$certfile" 2>/dev/null | ${pkgs.gnused}/bin/sed 's/notAfter=//')
            if [[ -n "$enddate" ]]; then
              end_epoch=$(${pkgs.coreutils}/bin/date -d "$enddate" +%s 2>/dev/null || true)
              now_epoch=$(${pkgs.coreutils}/bin/date +%s)
              if [[ -n "$end_epoch" ]]; then
                days_left=$(( (end_epoch - now_epoch) / 86400 ))
                printf '%s: %d days remaining\n' "$domain" "$days_left" >&3
              fi
            fi
            if ! ${pkgs.openssl}/bin/openssl x509 \
              -checkend $((${toString certExpiryWarnDays} * 86400)) \
              -noout -in "$certfile" 2>/dev/null; then
              FAILURES+=("$domain")
            fi
          done
          if [[ ''${#FAILURES[@]} -gt 0 ]]; then
            echo "Expiring within ${toString certExpiryWarnDays} days:"
            printf '  %s\n' "''${FAILURES[@]}"
            exit 1
          fi
        '';

        smartDiskExpr = ''
          CHECKED=()
          while read -r name type; do
            [[ "$type" == "disk" ]] || continue
            dev="/dev/$name"
            case "$dev" in
              /dev/sd[a-z]|/dev/nvme[0-9]*n[0-9]*) ;;
              *) continue ;;
            esac
            if ${pkgs.util-linux}/bin/lsblk -rno MOUNTPOINT "$dev" 2>/dev/null \
              | ${pkgs.gnugrep}/bin/grep -qv '^$'; then
              CHECKED+=("$dev")
            fi
          done < <(${pkgs.util-linux}/bin/lsblk -dnro NAME,TYPE 2>/dev/null)
          if [[ ''${#CHECKED[@]} -eq 0 ]]; then
            echo "No mounted SATA/NVMe devices found" >&3
            exit 0
          fi
          SMART_FAILED=0
          for disk in "''${CHECKED[@]}"; do
            if ${pkgs.smartmontools}/bin/smartctl -H "$disk" 2>&1 \
              | ${pkgs.gnugrep}/bin/grep -qE "PASSED|OK"; then
              printf '[OK ] %s\n' "$disk" >&3
            else
              printf '[FAIL] %s\n' "$disk" >&3
              SMART_FAILED=$((SMART_FAILED + 1))
            fi
          done
          if [[ $SMART_FAILED -gt 0 ]]; then
            exit 1
          fi
        '';

        allRegularChecks = {
          "Server is up" = "true";
          "No failed system services" = "${pkgs.systemd}/bin/systemctl --failed --quiet";
          "No failed user services" = ''
            ${pkgs.systemd}/bin/systemctl is-active --quiet "user@${mainUserUid}.service" 2>/dev/null || exit 0
            ${pkgs.systemd}/bin/systemctl --user --failed --quiet --machine=${mainUser}@.host
          '';
          "Memory and swap free" = memoryCheckExpr;
        }
        // lib.listToAttrs (
          map (svc: {
            name = "${svc} running";
            value = makeServiceActiveCheck svc;
          }) requireServicesUp
        )
        // regularHealthChecks;

        allDailyChecks =
          lib.optionalAttrs checkDiskUsage { "Disk space" = diskUsageExpr; }
          // lib.optionalAttrs checkCertExpiry { "Certificate expiry" = certExpiryExpr; }
          // lib.optionalAttrs checkSmartDisk { "SMART disk health" = smartDiskExpr; }
          // dailyHealthChecks;

        runCheckBlock =
          desc: script:
          let
            infoFile = "$TMPDIR_HC/info-${sanitizeName desc}";
            outFile = "$TMPDIR_HC/out-${sanitizeName desc}";
          in
          ''
            TOTAL=$((TOTAL + 1))
            if ${script} 3>"${infoFile}" >"${outFile}" 2>&1; then
              printf '[OK ] %s\n' ${lib.escapeShellArg desc} >> "$DETAIL_FILE"
            else
              printf '[FAIL] %s\n' ${lib.escapeShellArg desc} >> "$DETAIL_FILE"
              if [[ -s "${outFile}" ]]; then
                { printf 'check failed: %s\n' ${lib.escapeShellArg desc}
                  ${pkgs.coreutils}/bin/cat "${outFile}"
                } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
              fi
              FAILED=$((FAILED + 1))
            fi
            if [[ -s "${infoFile}" ]]; then
              ${pkgs.gnused}/bin/sed 's/^/  /' "${infoFile}" \
                | ${pkgs.coreutils}/bin/head -10 >> "$DETAIL_FILE"
            fi
          '';

        curlWithRetry =
          {
            endpointName,
            networkTimeoutSec,
            urlPath ? null,
            includeBody ? true,
            failOnTimeout ? true,
          }:
          let
            sleepInterval = if networkTimeoutSec <= 60 then "10" else "60";
            dynamicPath = urlPath == null;
            pushover = config.nx.linux.notifications.pushover;
            notifyCreatedCheck =
              if pushover.send == null then
                ""
              else
                pushover.send {
                  title = "Healthchecks.io";
                  message = "Auto-created check: ${endpointName}";
                  type = "info";
                  url = projectUrl;
                  urlTitle = "View all checks";
                };
          in
          ''
            : ''${TMPDIR_HC:?TMPDIR_HC must be set by the calling script}
            CURL_CONFIG="$TMPDIR_HC/curl-config"
            ${pkgs.coreutils}/bin/touch "$CURL_CONFIG"
            ${pkgs.coreutils}/bin/chmod 600 "$CURL_CONFIG"
            PING_KEY=$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg secretPath})
            ${
              if dynamicPath then
                ''
                  if [[ ''${FAILED:-0} -eq 0 ]]; then
                    printf 'url = %s/%s/${endpointName}?create=1\n' \
                      "${pingBaseUrl}" "$PING_KEY" > "$CURL_CONFIG"
                  else
                    printf 'url = %s/%s/${endpointName}/fail?create=1\n' \
                      "${pingBaseUrl}" "$PING_KEY" > "$CURL_CONFIG"
                  fi
                ''
              else
                ''
                  printf 'url = %s/%s/${endpointName}${urlPath}?create=1\n' \
                    "${pingBaseUrl}" "$PING_KEY" > "$CURL_CONFIG"
                ''
            }
            ${lib.optionalString includeBody ''
              if [[ ''${FAILED:-0} -gt 0 ]]; then
                ${pkgs.coreutils}/bin/cat "''${REPORT_FILE:-$TMPDIR_HC/report}" \
                  | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p notice
              fi
              ${pkgs.coreutils}/bin/head -c 100000 "''${REPORT_FILE:-$TMPDIR_HC/report}" > "$TMPDIR_HC/report-trunc"
              ${pkgs.coreutils}/bin/mv "$TMPDIR_HC/report-trunc" "''${REPORT_FILE:-$TMPDIR_HC/report}"
              printf 'data-binary = @%s\n' "''${REPORT_FILE:-$TMPDIR_HC/report}" >> "$CURL_CONFIG"
            ''}
            MAX_WAIT=${toString networkTimeoutSec}
            WAITED=0
            CURL_ERR="$TMPDIR_HC/curl-err"
            while true; do
              HTTP_CODE=$(${pkgs.curl}/bin/curl -sS -m 30 --connect-timeout 10 \
                --config "$CURL_CONFIG" -w '%{http_code}' -o /dev/null 2>"$CURL_ERR" || true)
              if [[ "$HTTP_CODE" =~ ^2[0-9]{2}$ ]]; then
                if [[ "$HTTP_CODE" == "201" ]]; then
                  echo "Healthchecks.io check auto-created: ${endpointName}" \
                    | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p notice
                  ${notifyCreatedCheck}
                fi
                break
              fi
              if [[ -s "$CURL_ERR" ]]; then
                ${pkgs.coreutils}/bin/cat "$CURL_ERR" \
                  | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
              fi
              if [[ $WAITED -ge $MAX_WAIT ]]; then
                echo "Failed to reach healthchecks endpoint after ${toString networkTimeoutSec}s" >&2
                ${if failOnTimeout then "exit 1" else "break"}
              fi
              ${pkgs.coreutils}/bin/sleep ${sleepInterval}
              WAITED=$((WAITED + ${sleepInterval}))
            done
          '';

        makeTimerScript =
          {
            endpointName,
            checks,
            networkTimeoutSec,
          }:
          let
            checkScripts = lib.mapAttrs makeCheckScript checks;
          in
          pkgs.writeShellScript "nx-hc-${endpointName}" ''
            set -euo pipefail
            TMPDIR_HC=$(${pkgs.coreutils}/bin/mktemp -d)
            trap "${pkgs.coreutils}/bin/rm -rf '$TMPDIR_HC'" EXIT
            REPORT_FILE="$TMPDIR_HC/report"
            DETAIL_FILE="$TMPDIR_HC/detail"
            FAILED=0
            TOTAL=0

            ${lib.concatStringsSep "\n" (lib.mapAttrsToList runCheckBlock checkScripts)}

            if [[ $FAILED -eq 0 ]]; then
              echo "All checks are healthy." > "$REPORT_FILE"
            else
              PASSED=$((TOTAL - FAILED))
              echo "$PASSED/$TOTAL checks are healthy." > "$REPORT_FILE"
            fi
            echo "" >> "$REPORT_FILE"
            ${pkgs.coreutils}/bin/cat "$DETAIL_FILE" >> "$REPORT_FILE"

            ${curlWithRetry { inherit endpointName networkTimeoutSec; }}
          '';

        makeStartPingScript =
          endpointName:
          pkgs.writeShellScript "nx-hc-start-${endpointName}" ''
            set -euo pipefail
            TMPDIR_HC=$(${pkgs.coreutils}/bin/mktemp -d)
            trap "${pkgs.coreutils}/bin/rm -rf '$TMPDIR_HC'" EXIT
            REPORT_FILE="$TMPDIR_HC/report"
            FAILED=0
            ${curlWithRetry {
              inherit endpointName;
              networkTimeoutSec = 60;
              urlPath = "/start";
              includeBody = false;
              failOnTimeout = false;
            }}
            exit 0
          '';

        makeServiceStopScript =
          {
            endpointName,
            triggerUnit,
            checkScript,
            includeLogs,
          }:
          let
            compiledCheckScript =
              if checkScript != null then makeCheckScript "svc-${endpointName}" checkScript else null;
          in
          pkgs.writeShellScript "nx-hc-stop-${endpointName}" ''
            set -euo pipefail
            TMPDIR_HC=$(${pkgs.coreutils}/bin/mktemp -d)
            trap "${pkgs.coreutils}/bin/rm -rf '$TMPDIR_HC'" EXIT
            REPORT_FILE="$TMPDIR_HC/report"
            DETAIL_FILE="$TMPDIR_HC/detail"
            FAILED=0
            TOTAL=0

            TOTAL=$((TOTAL + 1))
            if [[ "''${EXIT_STATUS:-0}" != "0" ]]; then
              printf '[FAIL] %s (exit %s)\n' ${lib.escapeShellArg triggerUnit} "''${EXIT_STATUS:-?}" >> "$DETAIL_FILE"
              FAILED=$((FAILED + 1))
            else
              printf '[OK ] %s\n' ${lib.escapeShellArg triggerUnit} >> "$DETAIL_FILE"
            fi

            ${lib.optionalString (compiledCheckScript != null) ''
              TOTAL=$((TOTAL + 1))
              INFO_FILE_CS="$TMPDIR_HC/info-checkscript"
              OUT_FILE_CS="$TMPDIR_HC/out-checkscript"
              if ${compiledCheckScript} 3>"$INFO_FILE_CS" >"$OUT_FILE_CS" 2>&1; then
                printf '[OK ] additional check\n' >> "$DETAIL_FILE"
              else
                printf '[FAIL] additional check\n' >> "$DETAIL_FILE"
                if [[ -s "$OUT_FILE_CS" ]]; then
                  { printf 'service check failed: %s\n' ${lib.escapeShellArg endpointName}
                    ${pkgs.coreutils}/bin/cat "$OUT_FILE_CS"
                  } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
                fi
                FAILED=$((FAILED + 1))
              fi
              if [[ -s "$INFO_FILE_CS" ]]; then
                ${pkgs.gnused}/bin/sed 's/^/  /' "$INFO_FILE_CS" \
                  | ${pkgs.coreutils}/bin/head -10 >> "$DETAIL_FILE"
              fi
            ''}

            if [[ $FAILED -eq 0 ]]; then
              echo "All checks are healthy." > "$REPORT_FILE"
            else
              PASSED=$((TOTAL - FAILED))
              echo "$PASSED/$TOTAL checks are healthy." > "$REPORT_FILE"
            fi
            echo "" >> "$REPORT_FILE"
            ${pkgs.coreutils}/bin/cat "$DETAIL_FILE" >> "$REPORT_FILE"

            ${lib.optionalString includeLogs ''
              LOG_FILE="$TMPDIR_HC/service-logs"
              ${pkgs.systemd}/bin/journalctl -u ${lib.escapeShellArg triggerUnit} \
                --no-pager --output=short -n 500 > "$LOG_FILE" 2>/dev/null || true
              if [[ -s "$LOG_FILE" ]]; then
                LOG_HDR=$'\nLogs (${triggerUnit}):\n'
                LOG_HDR_SIZE=''${#LOG_HDR}
                LOG_ELLIPSIS=$'\n[...]\n'
                LOG_ELLIPSIS_SIZE=''${#LOG_ELLIPSIS}
                LOG_FIRST_BYTES=100
                REPORT_SIZE=$(${pkgs.coreutils}/bin/wc -c < "$REPORT_FILE")
                LOG_SIZE=$(${pkgs.coreutils}/bin/wc -c < "$LOG_FILE")
                REMAINING=$((100000 - REPORT_SIZE - LOG_HDR_SIZE))
                if [[ $REMAINING -gt 0 ]]; then
                  printf '%s' "$LOG_HDR" >> "$REPORT_FILE"
                  if [[ $LOG_SIZE -le $REMAINING ]]; then
                    ${pkgs.coreutils}/bin/cat "$LOG_FILE" >> "$REPORT_FILE"
                  else
                    TAIL_BYTES=$((REMAINING - LOG_FIRST_BYTES - LOG_ELLIPSIS_SIZE))
                    if [[ $TAIL_BYTES -lt 300 ]]; then
                      ${pkgs.coreutils}/bin/tail -c "$REMAINING" "$LOG_FILE" >> "$REPORT_FILE"
                    else
                      ${pkgs.coreutils}/bin/head -c "$LOG_FIRST_BYTES" "$LOG_FILE" >> "$REPORT_FILE"
                      printf '%s' "$LOG_ELLIPSIS" >> "$REPORT_FILE"
                      ${pkgs.coreutils}/bin/tail -c "$TAIL_BYTES" "$LOG_FILE" >> "$REPORT_FILE"
                    fi
                  fi
                fi
              fi
            ''}

            ${curlWithRetry {
              inherit endpointName;
              networkTimeoutSec = 60;
            }}
            exit 0
          '';

        serviceCheckUnits = lib.mapAttrs' (
          key: entry:
          let
            entryName = sanitizeName key;
            endpointName = "${hostname}-${entryName}";
            triggerUnit = entry.trigger.runsAfter;
            serviceBaseName = lib.removeSuffix ".service" triggerUnit;
            checkScript = entry.check.checkScript;
            includeLogs = entry.includeLogs;
          in
          lib.nameValuePair serviceBaseName {
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              ExecStartPre = lib.mkBefore [ "-${makeStartPingScript endpointName}" ];
              ExecStopPost = lib.mkAfter [
                "-${
                  makeServiceStopScript {
                    inherit
                      endpointName
                      triggerUnit
                      checkScript
                      includeLogs
                      ;
                  }
                }"
              ];
            };
          }
        ) servicesHealthChecks;

      in
      lib.mkMerge [
        {
          assertions = [
            {
              assertion =
                (pingBaseUrl == "https://hc-ping.com") == (healthchecksBaseUrl == "https://healthchecks.io");
              message = "linux.server.healthchecks: pingBaseUrl and healthchecksBaseUrl must both be overridden for self-hosted instances (only one is still at its default)!";
            }
            {
              assertion = lib.hasPrefix "https://" pingBaseUrl;
              message = "linux.server.healthchecks: pingBaseUrl must use HTTPS!";
            }
            {
              assertion = lib.hasPrefix "https://" healthchecksBaseUrl;
              message = "linux.server.healthchecks: healthchecksBaseUrl must use HTTPS!";
            }
            {
              assertion = helpers.isValidUUID projectUUID;
              message = "linux.server.healthchecks: projectUUID must be a valid UUID!";
            }
          ];

          sops.secrets."${hostname}-healthchecks-uuid" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "healthchecks-uuid";
            mode = "0400";
            owner = "root";
            group = "root";
          };
        }

        (lib.mkIf effectiveRegular {
          systemd.services.nx-healthcheck-regular = {
            description = "Regular server health check";
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              TimeoutStartSec = serviceTimeoutSec;
              SuccessExitStatus = 1;
              ExecStart = makeTimerScript {
                endpointName = regularEndpointName;
                checks = allRegularChecks;
                networkTimeoutSec = 60;
              };
            };
          };

          systemd.timers.nx-healthcheck-regular = {
            description = "Regular server health check timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = healthInterval;
              OnUnitInactiveSec = healthInterval;
              Persistent = true;
              RandomizedDelaySec = healthRandomDelaySec;
            };
          };
        })

        (lib.mkIf effectiveDaily {
          systemd.services.nx-healthcheck-daily = {
            description = "Daily server health check";
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              TimeoutStartSec = serviceTimeoutSec;
              SuccessExitStatus = 1;
              ExecStart = makeTimerScript {
                endpointName = dailyEndpointName;
                checks = allDailyChecks;
                networkTimeoutSec = 900;
              };
            };
          };

          systemd.timers.nx-healthcheck-daily = {
            description = "Daily server health check timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = dailyHealthCheckSchedule;
              Persistent = true;
              RandomizedDelaySec = dailyRandomDelaySec;
            };
          };
        })

        (lib.mkIf hasServiceChecks {
          systemd.services = serviceCheckUnits;
        })
      ];
  };
}
