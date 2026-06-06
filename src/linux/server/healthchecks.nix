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

    tempMaxCelsius = lib.mkOption {
      type = lib.types.int;
      default = 79;
      description = "Maximum temperature in Celsius across all thermal zones before the temperature check fails.";
    };

    tempInfoCelsius = lib.mkOption {
      type = lib.types.int;
      default = 57;
      description = "Minimum temperature in Celsius at which thermal readings are included in health check output.";
    };

    loadMaxPerCore = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Maximum 5-minute load average per CPU core before the load check fails.";
    };

    loadBuildMultiplier = lib.mkOption {
      type = lib.types.float;
      default = 1.5;
      description = "Multiplier applied to the load threshold during and shortly after detected nix builds.";
    };

    loadBuildGraceSeconds = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Seconds to keep the relaxed load threshold after detected nix build activity.";
    };

    loadHighCpuExemptCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Process command names (matched as substrings against comm, not full args) that can trigger high-load-exempt mode when their CPU usage exceeds requiredCPUForHighLoadDetection.";
    };

    requiredCPUForHighLoadDetection = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Minimum CPU percentage a matching process must consume to activate high-load-exempt mode.";
    };

    loadHighCpuExemptCommandsSensitive = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Process command substrings that activate high-load-exempt mode at a lower CPU threshold, for background processes that spread load across many workers.";
    };

    requiredCPUForSensitiveHighLoadDetection = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Minimum CPU percentage a sensitive-matched process must consume to activate high-load-exempt mode.";
    };

    highLoadMultiplier = lib.mkOption {
      type = lib.types.float;
      default = 2.3;
      description = "Load limit multiplier applied when high-load-exempt mode is active.";
    };

    memoryFreeThresholdPct = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Minimum combined free percentage of (MemAvailable+SwapFree) relative to (MemTotal+SwapTotal) before the memory check fails.";
    };

    memoryRamUsedMaxPct = lib.mkOption {
      type = lib.types.int;
      default = 90;
      description = "Maximum RAM-only used percentage (MemTotal-MemAvailable)/MemTotal before the memory check fails, regardless of swap availability.";
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

    checkUptime = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Fail the daily check when uptime exceeds uptimeWarnDays, indicating no kernel updates were applied for that timeframe.";
    };

    uptimeWarnDays = lib.mkOption {
      type = lib.types.int;
      default = 90;
      description = "Number of days of continuous uptime after which the uptime check fails.";
    };

    checkSmartDisk = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run SMART health checks on mounted SATA and NVMe block devices.";
    };

    enableMonthlyHealthCheck = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable the monthly health check timer. Auto-enables in server and managed deployment modes.";
    };

    monthlyName = lib.mkOption {
      type = lib.types.str;
      default = "health-monthly";
      description = "Endpoint name suffix for the monthly check, prefixed with the hostname.";
    };

    monthlyHealthCheckSchedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-01 04:00:00";
      description = "OnCalendar schedule for the monthly health check.";
    };

    monthlyRandomDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "RandomizedDelaySec for the monthly health check timer in seconds.";
    };

    monthlyHealthChecks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional checks for the monthly health check, as attrset of description to bash expression.";
    };

    monthlyServiceTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 86400;
      description = "TimeoutStartSec for the monthly health check service in seconds.";
    };

    checkBtrfsScrub = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run btrfs scrub and device stats on all mounted btrfs filesystems.";
    };

    serviceTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 1200;
      description = "TimeoutStartSec for all generated health check services in seconds.";
    };

    minimalDetailMaxLines = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Minimum number of fd 3 detail lines reserved per check in the health check body.";
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

    healthchecksFinalChecksURL = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Computed URL to the healthchecks.io project checks page.";
    };

    servicesHealthChecks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            trigger = lib.mkOption {
              type = lib.types.submodule {
                options.service = lib.mkOption {
                  type = lib.types.str;
                  description = "Service unit this check is linked to.";
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

    timedHealthChecks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            checks = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = "Named checks for this standalone timed health check, using the same key format as regular checks.";
            };
            interval = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Interval for this standalone timed health check. When both interval and schedule are null, a default interval of 15m is used.";
            };
            schedule = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "OnCalendar schedule for this standalone timed health check.";
            };
            randomDelaySec = lib.mkOption {
              type = lib.types.int;
              default = 120;
              description = "RandomizedDelaySec for this standalone timed health check timer in seconds.";
            };
            timeoutSec = lib.mkOption {
              type = lib.types.int;
              default = 1200;
              description = "TimeoutStartSec for this standalone timed health check service in seconds.";
            };
            networkTimeoutSec = lib.mkOption {
              type = lib.types.int;
              default = 60;
              description = "Time in seconds to keep retrying the ping endpoint for this standalone timed health check.";
            };
          };
        }
      );
      default = { };
      description = "Independent timer-backed health checks, keyed by endpoint name suffix.";
    };

    enableSecretReplacements = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Replace and redact known sensitive literals such as hostname and domain in health check output.";
    };
  };

  module = {
    enabled = config: {
      nx.linux.server.healthchecks.healthchecksFinalChecksURL =
        "${config.nx.linux.server.healthchecks.healthchecksBaseUrl}/projects/${config.nx.linux.server.healthchecks.projectUUID}/checks/";
      nx.linux.server.healthchecks.requireServicesUp = [ "nix-daemon.service" ];
      nx.linux.server.healthchecks.loadHighCpuExemptCommandsSensitive =
        let
          monthly = config.nx.linux.server.healthchecks.enableMonthlyHealthCheck;
          mode = config.nx.global.deploymentMode;
          monthlyActive = if monthly != null then monthly else mode == "server" || mode == "managed";
        in
        lib.optional (monthlyActive && config.nx.linux.server.healthchecks.checkBtrfsScrub) "btrfs-scrub";
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "nx-healthcheck";
          string = ".*";
        }
        {
          unitless = true;
          tag = "nx-healthcheck";
          string = ".*";
        }
        {
          tag = "systemd";
          service = "init.scope";
          string = "nx-healthchecks-[a-z][a-z0-9-]*\\.service";
        }
      ];
    };

    linux.home = config: {
      home.packages = [
        (pkgs.writeShellScriptBin "healthcheck-run" ''
          set -uo pipefail
          _arg="''${1:-}"
          case "$_arg" in
            regular|daily|monthly) _unit="nx-healthchecks-builtin-''${_arg}.service" ;;
            *) printf 'usage: healthcheck-run <regular|daily|monthly>\n' >&2; exit 1 ;;
          esac
          _start=$(${pkgs.coreutils}/bin/date +%s)
          sudo ${pkgs.systemd}/bin/systemctl start --wait "$_unit" || true
          ${pkgs.systemd}/bin/journalctl -u "$_unit" --since "@''${_start}" --no-pager
        '')
      ];
    };

    ifEnabled.linux.security.letsencrypt.enabled = config: {
      nx.linux.server.healthchecks.checkCertExpiry = lib.mkDefault true;
    };

    ifEnabled.linux.server.dashboard.enabled = config: {
      nx.linux.server.dashboard.services = [
        {
          name = "Healthchecks";
          group = "health";
          href = config.nx.linux.server.healthchecks.healthchecksFinalChecksURL;
          description = "Task and cron job monitoring";
          icon = "healthchecks";
          enableSiteMonitor = false;
          widgets = [
            {
              type = "healthchecks";
              url = config.nx.linux.server.healthchecks.healthchecksBaseUrl;
              key = "{{HOMEPAGE_VAR_HEALTHCHECKS_KEY}}";
            }
          ];
        }
      ];
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
        tempMaxCelsius,
        tempInfoCelsius,
        loadMaxPerCore,
        loadBuildMultiplier,
        loadBuildGraceSeconds,
        loadHighCpuExemptCommands,
        requiredCPUForHighLoadDetection,
        loadHighCpuExemptCommandsSensitive,
        requiredCPUForSensitiveHighLoadDetection,
        highLoadMultiplier,
        memoryFreeThresholdPct,
        memoryRamUsedMaxPct,
        enableDailyHealthCheck,
        dailyName,
        dailyHealthCheckSchedule,
        dailyRandomDelaySec,
        dailyHealthChecks,
        checkDiskUsage,
        diskFreeThresholdPct,
        checkCertExpiry,
        certExpiryWarnDays,
        checkUptime,
        uptimeWarnDays,
        checkSmartDisk,
        enableMonthlyHealthCheck,
        monthlyName,
        monthlyHealthCheckSchedule,
        monthlyRandomDelaySec,
        monthlyHealthChecks,
        monthlyServiceTimeoutSec,
        checkBtrfsScrub,
        servicesHealthChecks,
        timedHealthChecks,
        serviceTimeoutSec,
        minimalDetailMaxLines,
        healthchecksBaseUrl,
        projectUUID,
        healthchecksFinalChecksURL,
        enableSecretReplacements,
        ...
      }:
      let
        hostname = self.host.hostname;
        mainUser = self.host.mainUser.username;
        mainUserUid = toString config.users.users.${self.host.mainUser.username}.uid;
        deploymentMode = config.nx.global.deploymentMode;
        secretPath = config.sops.secrets."${hostname}-healthchecks-uuid".path;
        stateDir = "/var/lib/nx-healthchecks";
        dirtyMarkerPath = "${stateDir}/pending-clean-shutdown";
        crashMarkerPath = "${stateDir}/unclean-shutdown-detected";
        crashRecoveryDatePath = "${stateDir}/monthly-crash-recovery-last-date";

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

        effectiveMonthly =
          if enableMonthlyHealthCheck != null then
            enableMonthlyHealthCheck
          else
            deploymentMode == "server" || deploymentMode == "managed";

        hasServiceChecks = servicesHealthChecks != { };
        hasTimedChecks = timedHealthChecks != { };

        regularEndpointName = "${hostname}-${healthName}";
        dailyEndpointName = "${hostname}-${dailyName}";
        monthlyEndpointName = "${hostname}-${monthlyName}";

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

        stripGroupPrefix =
          key:
          let
            m = builtins.match ".*-(.*)" key;
          in
          if m != null then lib.trim (builtins.head m) else key;

        makeCheckScript =
          desc: cmd:
          pkgs.writeShellScript "nx-hc-check-${sanitizeName (lib.removePrefix "-" (lib.removePrefix "!" (lib.removePrefix "+" desc)))}" ''
            set -e
            ${cmd}
          '';

        servicesGroupedExpr = ''
          _svc_failed=0
          ${lib.concatMapStringsSep "\n" (svc: ''
            _elapsed=0
            _svc_ok=0
            while true; do
              _state=$(${pkgs.systemd}/bin/systemctl is-active ${lib.escapeShellArg svc} 2>/dev/null || true)
              if [[ "$_state" == "active" ]]; then
                _svc_ok=1
                break
              fi
              if [[ "$_state" != "activating" && "$_state" != "deactivating" && "$_state" != "reloading" && "$_state" != "inactive" ]]; then
                break
              fi
              if [[ $_elapsed -ge 30 ]]; then
                break
              fi
              ${pkgs.coreutils}/bin/sleep 1
              _elapsed=$((_elapsed + 1))
            done
            if [[ $_svc_ok -eq 1 ]]; then
              printf '[OK ] %s\n' ${lib.escapeShellArg svc} >&3
            else
              printf '[FAIL] %s\n' ${lib.escapeShellArg svc} >&3
              _svc_failed=$((_svc_failed + 1))
            fi
          '') requireServicesUp}
          if [[ $_svc_failed -gt 0 ]]; then
            exit 1
          fi
        '';

        memoryCheckExpr = ''
          ${pkgs.gawk}/bin/awk '
            /MemTotal/{t=$2} /MemAvailable/{a=$2} /SwapTotal/{st=$2} /SwapFree/{sf=$2}
            END{
              mem_used=(t>0) ? (t-a)*100/t : 0
              if (st > 0) {
                swap_used=(st-sf)*100/st
                combined_free=(a+sf)*100/(t+st)
                if (mem_used > 35 || swap_used > 35) printf "%.0f%% mem, %.0f%% swap\n", mem_used, swap_used > "/dev/fd/3"
              } else {
                combined_free=(t>0) ? a*100/t : 100
                if (mem_used > 35) printf "%.0f%% mem\n", mem_used > "/dev/fd/3"
              }
              exit (combined_free < ${toString memoryFreeThresholdPct} || mem_used > ${toString memoryRamUsedMaxPct})
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
            printf '%s: %d%% used\n' "$mnt" "$pct" >&3
            if [[ $free_pct -lt ${toString diskFreeThresholdPct} ]]; then
              FAILURES+=("$mnt: $pct% used")
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

        thermalCheckExpr = ''
          _zone_count=0
          _temp_max=0
          _zone_names=()
          _zone_temps=()
          for _zone_file in /sys/class/thermal/thermal_zone*/temp; do
            [[ -f "$_zone_file" ]] || continue
            _temp_raw=$(${pkgs.coreutils}/bin/cat "$_zone_file" 2>/dev/null || true)
            [[ "$_temp_raw" =~ ^[0-9]+$ ]] || continue
            _temp_c=$((_temp_raw / 1000))
            _zone_dir="''${_zone_file%/temp}"
            _zone_names+=("''${_zone_dir##*/}")
            _zone_temps+=($_temp_c)
            _zone_count=$((_zone_count + 1))
            if [[ $_temp_c -gt $_temp_max ]]; then
              _temp_max=$_temp_c
            fi
          done
          if [[ $_zone_count -eq 0 ]]; then
            printf 'no thermal zones found\n' >&3
            exit 0
          fi
          if [[ $_temp_max -ge ${toString tempInfoCelsius} ]]; then
            if [[ $_zone_count -eq 1 ]]; then
              printf 'core: %dC\n' "$_temp_max" >&3
            else
              for (( _i=0; _i<_zone_count; _i++ )); do
                printf '%s: %dC\n' "''${_zone_names[$_i]}" "''${_zone_temps[$_i]}" >&3
              done
            fi
          fi
          if [[ $_temp_max -ge ${toString tempMaxCelsius} ]]; then
            exit 1
          fi
        '';

        loadCheckExpr =
          let
            awkCondTop = lib.concatStringsSep " || " (
              map (p: "index($NF, \"${p}\") > 0") loadHighCpuExemptCommands
            );
            awkCondSensitive = lib.concatStringsSep " || " (
              map (p: "index($NF, \"${p}\") > 0") loadHighCpuExemptCommandsSensitive
            );
          in
          ''
            _build_marker=/run/nx-healthcheck/build-active
            _now=$(${pkgs.coreutils}/bin/date +%s)
            _build_mode=normal
            if ${pkgs.procps}/bin/ps -eo pid,etimes,cmd \
              | ${pkgs.gnugrep}/bin/grep -E 'nix build|nix-store.*realise|nix-store.*build' \
              | ${pkgs.gnugrep}/bin/grep -v grep >/dev/null; then
              ${pkgs.coreutils}/bin/touch "$_build_marker"
            fi
            if [[ -e "$_build_marker" ]]; then
              _marker_mtime=$(${pkgs.coreutils}/bin/stat -c %Y "$_build_marker" 2>/dev/null || echo 0)
              if [[ $((_now - _marker_mtime)) -le ${toString loadBuildGraceSeconds} ]]; then
                _build_mode=build-active
              fi
            fi
            _high_load_mode=normal
            ${lib.optionalString (loadHighCpuExemptCommands != [ ]) ''
              if ${pkgs.gawk}/bin/awk -v thr=${toString requiredCPUForHighLoadDetection} '
                  ($9+0 >= thr && (${awkCondTop})) {found=1}
                  END{exit !found}
                ' "$TMPDIR_HC/top-data" 2>/dev/null; then
                _high_load_mode=high-load-exempt
              fi
            ''}
            ${lib.optionalString (loadHighCpuExemptCommandsSensitive != [ ]) ''
              if ${pkgs.gawk}/bin/awk -v thr=${toString requiredCPUForSensitiveHighLoadDetection} '
                  ($9+0 >= thr && (${awkCondSensitive})) {found=1}
                  END{exit !found}
                ' "$TMPDIR_HC/top-data" 2>/dev/null; then
                _high_load_mode=high-load-exempt
              fi
            ''}
            _nproc=$(${pkgs.coreutils}/bin/nproc 2>/dev/null || echo 1)
            ${pkgs.gawk}/bin/awk \
              -v max=${toString loadMaxPerCore} \
              -v build_multiplier=${toString loadBuildMultiplier} \
              -v high_multiplier=${toString highLoadMultiplier} \
              -v nproc="$_nproc" \
              -v build_mode="$_build_mode" \
              -v high_load_mode="$_high_load_mode" '
              {
                load5 = $2
                threshold = max * nproc
                mode = "normal"
                if (build_mode == "build-active") {
                  t = threshold * build_multiplier
                  if (t > threshold) { threshold = t; mode = "build-active" }
                }
                if (high_load_mode == "high-load-exempt") {
                  t = max * nproc * high_multiplier
                  if (t > threshold) { threshold = t; mode = "high-load-exempt" }
                }
                if (load5 >= 1.0 || mode != "normal") printf "load 5m: %.2f (%s cores, limit: %.1f, mode: %s)\n", load5, nproc, threshold, mode > "/dev/fd/3"
                exit (load5 > threshold)
              }
            ' /proc/loadavg
          '';

        stripProcCmd = pkgs.writeShellScript "nx-hc-strip-proc-cmd" ''
          ${pkgs.gawk}/bin/awk '{
            cmd = $1
            sub(/^\/nix\/store\/[^\/]+\/bin\//, "", cmd)
            sub(/^\/nix\/store\/[^\/]+\//, "", cmd)
            result = cmd
            for (i = 2; i <= NF; i++) {
              arg = $i
              gsub(/\/nix\/store\/[^-]+-/, "..", arg)
              result = result " " arg
            }
            print result
          }'
        '';

        networkRequiredIfaces =
          lib.optional config.virtualisation.docker.enable "docker0"
          ++ lib.optional config.services.tailscale.enable "tailscale0"
          ++ lib.optional (self.host.ethernetDeviceName != null) self.host.ethernetDeviceName
          ++ lib.optional (self.host.wifiDeviceName != null) self.host.wifiDeviceName;

        networkIfaceExpr = ''
          _ifaces=$(${pkgs.iproute2}/bin/ip -o addr show up scope global 2>/dev/null \
            | ${pkgs.gawk}/bin/awk '$3=="inet"{print $2 ": " $4}')
          _missing=()
          ${lib.concatMapStringsSep "\n" (iface: ''
            if ! printf '%s\n' "$_ifaces" | ${pkgs.gnugrep}/bin/grep -q '^${iface}:'; then
              _missing+=("${iface}")
            fi
          '') networkRequiredIfaces}
          if [[ ''${#_missing[@]} -gt 0 ]]; then
            printf '%s: <no ip>\n' "''${_missing[@]}" >&3
            if [[ -n "$_ifaces" ]]; then
              printf '%s\n' "$_ifaces" >&3
            fi
            exit 1
          fi
        '';

        timezoneExpr = ''
          _tz=$(${pkgs.systemd}/bin/timedatectl show --property=Timezone --value 2>/dev/null || true)
          if [[ -n "$_tz" && "$_tz" != ${lib.escapeShellArg config.time.timeZone} ]]; then
            printf 'timezone: %s (expected: %s)\n' "$_tz" ${lib.escapeShellArg config.time.timeZone} >&3
            exit 1
          fi
        '';

        remoteIpExpr = ''
          _remote_cache=/run/nx-healthcheck/remote-ip
          _cache_age=99999
          if [[ -f "$_remote_cache" ]]; then
            _cache_age=$(( $(${pkgs.coreutils}/bin/date +%s) - $(${pkgs.coreutils}/bin/stat -c %Y "$_remote_cache") ))
          fi
          _raw=""
          if [[ $_cache_age -ge 600 ]]; then
            _raw=$(${pkgs.curl}/bin/curl -sf --max-time 10 https://api.ipify.org 2>/dev/null || true)
          fi
          if [[ "$_raw" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            printf '%s' "$_raw" > "$_remote_cache" || true
            printf '%s\n' "$_raw" >&3
          elif [[ -f "$_remote_cache" ]]; then
            _cached=$(${pkgs.coreutils}/bin/cat "$_remote_cache")
            if [[ $_cache_age -ge 600 ]]; then
              printf '%s (cached)\n' "$_cached" >&3
            else
              printf '%s\n' "$_cached" >&3
            fi
          else
            printf '<no remote ip>\n' >&3
          fi
        '';

        topSnapshotExpr = ''
          _hc_snap_start=$(${pkgs.coreutils}/bin/date +%s)
          ${pkgs.gawk}/bin/awk '$3 !~ /^loop|^dm-|^ram/ {rs+=$6; ws+=$10} END{print rs, ws}' /proc/diskstats > "$TMPDIR_HC/diskstats-before" 2>/dev/null || true
          ${pkgs.gawk}/bin/awk 'NR>2 && $1 != "lo:" {rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev > "$TMPDIR_HC/netdev-before" 2>/dev/null || true
          ${pkgs.procps}/bin/top -c -w 512 -bn2 -d10 2>/dev/null \
            | ${pkgs.gawk}/bin/awk -v cpu_out="$TMPDIR_HC/top-cpu-summary" '
                /^top/{b++; next}
                b<2{next}
                /^%Cpu/{print > cpu_out; next}
                /^Tasks|^MiB|^ *PID/{next}
                NF==0{next}
                $NF=="top"{next}
                {print}
              ' > "$TMPDIR_HC/top-data" || true
          _hc_snap_end=$(${pkgs.coreutils}/bin/date +%s)
          _hc_snap_elapsed=$((_hc_snap_end - _hc_snap_start))
          [[ $_hc_snap_elapsed -lt 1 ]] && _hc_snap_elapsed=1
          printf '%d\n' "$_hc_snap_elapsed" > "$TMPDIR_HC/snapshot-elapsed"
          ${pkgs.gawk}/bin/awk '$3 !~ /^loop|^dm-|^ram/ {rs+=$6; ws+=$10} END{print rs, ws}' /proc/diskstats > "$TMPDIR_HC/diskstats-after" 2>/dev/null || true
          ${pkgs.gawk}/bin/awk 'NR>2 && $1 != "lo:" {rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev > "$TMPDIR_HC/netdev-after" 2>/dev/null || true
          exit 0
        '';

        cpuUsageExpr = ''
          if [[ -f "$TMPDIR_HC/top-cpu-summary" ]]; then
            ${pkgs.gawk}/bin/awk '
              BEGIN{idle=0}
              {for(i=1;i<=NF;i++) if($i=="id,") idle=$(i-1)+0}
              END{pct=100-idle; if(pct>=5) printf "%.0f%%\n", pct > "/dev/fd/3"}
            ' "$TMPDIR_HC/top-cpu-summary"
          fi
          exit 0
        '';

        topCpuExpr = ''
          _n=0
          while IFS= read -r _line; do
            _n=$((_n + 1))
            _cpu=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{printf "%5.1f%%", $9}')
            _raw=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{r=""; for(i=12;i<=NF;i++) r=r (r==""?"": " ") $i; print r}')
            if [[ -n "$_raw" ]]; then
              _cmd=$(printf '%s' "$_raw" | ${stripProcCmd} | ${secretCensorScript})
            else
              _cmd=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $NF}')
            fi
            if [[ -z "$_cmd" ]]; then
              _cmd=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $NF}')
            fi
            if [[ -z "$_cmd" ]]; then
              _cmd="<unknown>"
            fi
            printf '%2d. %s %s\n' "$_n" "$_cpu" "$_cmd" >&3
          done < <(${pkgs.gawk}/bin/awk '
              { val=$9+0
                if (val<1.0) exit
                if (val>5) { print; above++; next }
                if (above+below<10) { print; below++; next }
                exit }
            ' "$TMPDIR_HC/top-data" 2>/dev/null) || true
          exit 0
        '';

        topMemExpr = ''
          _n=0
          while IFS= read -r _line; do
            _n=$((_n + 1))
            _mem=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{printf "%5.1f%%", $10}')
            _raw=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{r=""; for(i=12;i<=NF;i++) r=r (r==""?"": " ") $i; print r}')
            if [[ -n "$_raw" ]]; then
              _cmd=$(printf '%s' "$_raw" | ${stripProcCmd} | ${secretCensorScript})
            else
              _cmd=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $NF}')
            fi
            if [[ -z "$_cmd" ]]; then
              _cmd=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $NF}')
            fi
            if [[ -z "$_cmd" ]]; then
              _cmd="<unknown>"
            fi
            printf '%2d. %s %s\n' "$_n" "$_mem" "$_cmd" >&3
          done < <(${pkgs.coreutils}/bin/sort -rn -k10 "$TMPDIR_HC/top-data" 2>/dev/null \
            | ${pkgs.gawk}/bin/awk '
                { val=$10+0
                  if (val<2.5) exit
                  if (val>5) { print; above++; next }
                  if (above+below<10) { print; below++; next }
                  exit }
              ') || true
          exit 0
        '';

        ioRateExpr = ''
          if [[ -f "$TMPDIR_HC/diskstats-before" && -f "$TMPDIR_HC/diskstats-after" && -f "$TMPDIR_HC/snapshot-elapsed" ]]; then
            _elapsed=$(${pkgs.coreutils}/bin/cat "$TMPDIR_HC/snapshot-elapsed")
            ${pkgs.gawk}/bin/awk -v elapsed="$_elapsed" '
              NR==1{br=$1; bw=$2}
              NR==2{reads=($1-br)/elapsed/2048; writes=($2-bw)/elapsed/2048
                if (reads>=1.2 || writes>=1.2) printf "reads: %.1f MB/s, writes: %.1f MB/s\n", reads, writes > "/dev/fd/3"}
            ' "$TMPDIR_HC/diskstats-before" "$TMPDIR_HC/diskstats-after"
          fi
          exit 0
        '';

        networkTrafficExpr = ''
          if [[ -f "$TMPDIR_HC/netdev-before" && -f "$TMPDIR_HC/netdev-after" && -f "$TMPDIR_HC/snapshot-elapsed" ]]; then
            _elapsed=$(${pkgs.coreutils}/bin/cat "$TMPDIR_HC/snapshot-elapsed")
            ${pkgs.gawk}/bin/awk -v elapsed="$_elapsed" '
              NR==1{brx=$1; btx=$2}
              NR==2{rx=($1-brx)/elapsed/1048576; tx=($2-btx)/elapsed/1048576
                if (rx>=0.2 || tx>=0.2) printf "RX: %.1f MB/s, TX: %.1f MB/s\n", rx, tx > "/dev/fd/3"}
            ' "$TMPDIR_HC/netdev-before" "$TMPDIR_HC/netdev-after"
          fi
          exit 0
        '';

        iowaitExpr = ''
          if [[ -f "$TMPDIR_HC/top-cpu-summary" ]]; then
            _iowait=$(${pkgs.gawk}/bin/awk '
              {for(i=1;i<=NF;i++) if($i=="wa,") {printf "%.0f", $(i-1)+0; exit}}
            ' "$TMPDIR_HC/top-cpu-summary")
            if [[ -n "$_iowait" ]]; then
              printf '%s%% iowait\n' "$_iowait" >&3
              if [[ $_iowait -ge 60 ]]; then
                exit 1
              fi
            fi
          fi
          exit 0
        '';

        storageHealthExpr = ''
          _failed=0

          for _path in /run /tmp; do
            if ! ${pkgs.coreutils}/bin/test -w "$_path" 2>/dev/null; then
              printf '%s: not writable\n' "$_path" >&3
              _failed=1
            fi
          done

          if ! ${pkgs.coreutils}/bin/touch "$TMPDIR_HC/.write-test" 2>/dev/null; then
            printf '/tmp: cannot create file\n' >&3
            _failed=1
          fi

          if ! ${pkgs.coreutils}/bin/timeout 5 ${pkgs.coreutils}/bin/stat /nix/store >/dev/null 2>&1; then
            printf '/nix/store: stat timeout or error\n' >&3
            _failed=1
          fi

          while read -r _dev _mp _type _opts _rest; do
            case "$_mp" in /nix|/persist) ;; *) continue ;; esac
            case "$_type" in squashfs|iso9660|romfs|cramfs) continue ;; esac
            case ",$_opts," in
              *,ro,*)
                printf '%s: mounted read-only\n' "$_mp" >&3
                _failed=1
                ;;
            esac
          done < /proc/mounts

          for _state_file in /sys/class/nvme/nvme*/state; do
            [[ -f "$_state_file" ]] || continue
            _nvme_name="''${_state_file%/state}"
            _nvme_name="''${_nvme_name##*/}"
            _state=$(${pkgs.coreutils}/bin/cat "$_state_file" 2>/dev/null || echo unknown)
            if [[ "$_state" == "dead" ]]; then
              printf '%s: %s\n' "$_nvme_name" "$_state" >&3
              _failed=1
            fi
          done

          if [[ $_failed -ne 0 ]]; then
            exit 1
          fi
        '';

        allRegularChecks = {
          "+00 - Process snapshot" = topSnapshotExpr;
          "+10 - Server is up" = "true";
          "+40 - System services health" = ''
            _failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend --no-pager 2>/dev/null \
              | ${pkgs.gawk}/bin/awk 'NF>0{print $1}')
            if [[ -n "$_failed" ]]; then
              printf '%s\n' "$_failed" >&3
              exit 1
            fi
          '';
          "+40 - User services health" = ''
            ${pkgs.systemd}/bin/systemctl is-active --quiet "user@${mainUserUid}.service" 2>/dev/null || exit 0
            _failed=$(${pkgs.systemd}/bin/systemctl --user --failed --plain --no-legend --no-pager \
              --machine=${mainUser}@.host 2>/dev/null \
              | ${pkgs.gawk}/bin/awk 'NF>0{print $1}')
            if [[ -n "$_failed" ]]; then
              printf '%s\n' "$_failed" >&3
              exit 1
            fi
          '';
          "!20 - Memory and swap used" = memoryCheckExpr;
        }
        // lib.optionalAttrs (!self.isVirtual) { "!20 - Temperature" = thermalCheckExpr; }
        // {
          "!20 - Load" = loadCheckExpr;
          "!25 - CPU usage" = cpuUsageExpr;
        }
        // {
          "!26 - Disk IO" = ioRateExpr;
          "+26 - IO wait" = iowaitExpr;
          "!27 - Network traffic" = networkTrafficExpr;
        }
        // {
          "!30 - Network interfaces" = networkIfaceExpr;
          "+30 - Timezone" = timezoneExpr;
          "-30 - Remote IP" = remoteIpExpr;
        }
        // {
          "+45 - Storage health" = storageHealthExpr;
        }
        // lib.optionalAttrs (requireServicesUp != [ ]) { "50 - Services" = servicesGroupedExpr; }
        // {
          "!60 - Top CPU processes" = topCpuExpr;
          "!60 - Top memory processes" = topMemExpr;
        }
        // regularHealthChecks;

        uptimeCheckExpr = ''
          _uptime_sec=$(${pkgs.gawk}/bin/awk '{print int($1)}' /proc/uptime)
          _uptime_days=$((_uptime_sec / 86400))
          printf 'uptime: %d days\n' "$_uptime_days" >&3
          if [[ $_uptime_days -ge ${toString uptimeWarnDays} ]]; then
            exit 1
          fi
        '';

        kernelLogTodayExpr = ''
          KERNEL_LOG_ALL="$TMPDIR_HC/kernel-log-today-all"
          KERNEL_LOG_FILTERED="$TMPDIR_HC/kernel-log-today-filtered"
          _since=$(${pkgs.coreutils}/bin/date -d 'yesterday 00:00:00' '+%Y-%m-%d %H:%M:%S')

          ${pkgs.systemd}/bin/journalctl -k --since "$_since" --no-pager > "$KERNEL_LOG_ALL" 2>/dev/null || true
          _kernel_lines=$(${pkgs.coreutils}/bin/wc -l < "$KERNEL_LOG_ALL")

          if [[ "$_kernel_lines" -eq 0 ]]; then
            printf '[no kernel log lines today]\n' >&3
            exit 0
          fi

          if [[ "$_kernel_lines" -gt 200 ]]; then
            printf '[kernel log: warning+ only, %d lines today]\n' "$_kernel_lines" >&3
            ${pkgs.systemd}/bin/journalctl -k --since "$_since" -p warning..emerg --no-pager \
              | ${secretCensorScript} > "$KERNEL_LOG_FILTERED"
          else
            ${secretCensorScript} < "$KERNEL_LOG_ALL" > "$KERNEL_LOG_FILTERED"
          fi

          ${pkgs.coreutils}/bin/cat "$KERNEL_LOG_FILTERED" >&3
        '';

        allDailyChecks =
          lib.optionalAttrs checkUptime { "00 - Uptime" = uptimeCheckExpr; }
          // lib.optionalAttrs checkDiskUsage { "10 - Disk space" = diskUsageExpr; }
          // lib.optionalAttrs checkCertExpiry { "20 - Certificate expiry" = certExpiryExpr; }
          // lib.optionalAttrs (checkSmartDisk && config.nx.linux.storage.smartd.enable) {
            "30 - SMART disk health" = smartDiskExpr;
          }
          // {
            "90 - Kernel logs" = kernelLogTodayExpr;
          }
          // dailyHealthChecks;

        btrfsScrubExpr = ''
          BTRFS_FAILED=0
          BTRFS_COUNT=0
          while IFS= read -r _mp; do
            BTRFS_COUNT=$((BTRFS_COUNT + 1))
            _scrub_log="$TMPDIR_HC/scrub-$BTRFS_COUNT"
            _scrub_exit=0
            ${pkgs.btrfs-progs}/bin/btrfs scrub start -Bd "$_mp" 2>&1 \
              | ${pkgs.coreutils}/bin/tee "$_scrub_log" >&2
            _scrub_exit=''${PIPESTATUS[0]}
            if [[ $_scrub_exit -ne 0 ]]; then
              printf '%s: scrub errors\n' "$_mp" >&3
              ${pkgs.gnused}/bin/sed 's/^/  /' "$_scrub_log" >&3
              BTRFS_FAILED=1
              continue
            fi
            _scrub_info=$(${pkgs.gnugrep}/bin/grep -iE 'error summary|total.*scrub|duration' "$_scrub_log" 2>/dev/null \
              | ${pkgs.gnused}/bin/sed 's/^[[:space:]]*//')
            _stats_exit=0
            _stats=$(${pkgs.btrfs-progs}/bin/btrfs device stats -c "$_mp" 2>&1) || _stats_exit=$?
            printf '%s:\n' "$_mp" >&3
            if [[ -n "$_scrub_info" ]]; then
              printf '%s\n' "$_scrub_info" | ${pkgs.gnused}/bin/sed 's/^/  /' >&3
            fi
            if [[ $_stats_exit -eq 65 ]]; then
              printf '  Device stats:     failed\n' >&3
              printf '%s\n' "$_stats" | ${pkgs.gnused}/bin/sed 's/^/    /' >&3
              BTRFS_FAILED=1
              continue
            elif [[ $_stats_exit -ne 0 ]]; then
              _errs=$(printf '%s\n' "$_stats" | ${pkgs.gawk}/bin/awk '$NF+0 != 0 {print}')
              printf '  Device stats:     errors\n' >&3
              printf '%s\n' "$_errs" | ${pkgs.gnused}/bin/sed 's/^/    /' >&3
              BTRFS_FAILED=1
            else
              printf '  Device stats:     no errors found\n' >&3
            fi
          done < <(${pkgs.gawk}/bin/awk '$3 == "btrfs" && !seen[$1]++ {print $2}' /proc/mounts)
          if [[ $BTRFS_COUNT -eq 0 ]]; then
            printf 'no btrfs filesystems found\n' >&3
          fi
          exit "$BTRFS_FAILED"
        '';

        allMonthlyChecks =
          lib.optionalAttrs checkBtrfsScrub { "10 - Btrfs scrub" = btrfsScrubExpr; } // monthlyHealthChecks;

        runCheckBlock =
          desc: script:
          let
            silent = lib.hasPrefix "+" desc;
            infoOnly = lib.hasPrefix "!" desc;
            alwaysSucceed = lib.hasPrefix "-" desc;
            cleanDesc =
              if silent then
                lib.removePrefix "+" desc
              else if infoOnly then
                lib.removePrefix "!" desc
              else if alwaysSucceed then
                lib.removePrefix "-" desc
              else
                desc;
            infoFile = "$TMPDIR_HC/info-${sanitizeName cleanDesc}";
            outFile = "$TMPDIR_HC/out-${sanitizeName cleanDesc}";
            displayName = stripGroupPrefix cleanDesc;

            spacer = ''
              if [[ $_prev_had_info -eq 1 ]]; then
                printf '\n' >> "$DETAIL_FILE"
              fi
            '';
            appendInfo = ''
              _info_lines=$(${pkgs.coreutils}/bin/wc -l < "${infoFile}")
              ${pkgs.gnused}/bin/sed 's/^/  /' "${infoFile}" \
                | ${pkgs.coreutils}/bin/head -n "$DETAIL_MAX_LINES" >> "$DETAIL_FILE"
              if [[ "$_info_lines" -gt "$DETAIL_MAX_LINES" ]]; then
                printf '  [%d lines truncated]\n' "$((_info_lines - DETAIL_MAX_LINES))" >> "$DETAIL_FILE"
              fi
              _prev_had_info=1
            '';
            infoTail = ''
              if [[ -s "${infoFile}" ]]; then
                ${appendInfo}
              else
                _prev_had_info=0
              fi
            '';
            showIfInfo = ''
              if [[ -s "${infoFile}" ]]; then
                TOTAL=$((TOTAL + 1))
                ${spacer}
                printf '[OK ] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
                ${appendInfo}
              else
                SILENT=$((SILENT + 1))
              fi
            '';
            onFail = ''
              TOTAL=$((TOTAL + 1))
              FAILED=$((FAILED + 1))
              ${spacer}
              printf '[FAIL] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
              if [[ -s "${outFile}" ]]; then
                { printf 'check failed: %s\n' ${lib.escapeShellArg displayName}
                  ${pkgs.coreutils}/bin/cat "${outFile}"
                } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
              fi
              if [[ -s "${infoFile}" ]]; then
                { printf 'check details: %s\n' ${lib.escapeShellArg displayName}
                  ${pkgs.coreutils}/bin/cat "${infoFile}"
                } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
              fi
              ${infoTail}
            '';
          in
          if silent then
            ''
              if ! ${script} 3>"${infoFile}" >"${outFile}" 2>&1; then
                ${onFail}
              else
                SILENT=$((SILENT + 1))
              fi
            ''
          else if infoOnly then
            ''
              if ${script} 3>"${infoFile}" >"${outFile}" 2>&1; then
                ${showIfInfo}
              else
                ${onFail}
              fi
            ''
          else if alwaysSucceed then
            ''
              ${script} 3>"${infoFile}" >"${outFile}" 2>&1 || true
              ${showIfInfo}
            ''
          else
            ''
              ${spacer}
              TOTAL=$((TOTAL + 1))
              if ${script} 3>"${infoFile}" >"${outFile}" 2>&1; then
                printf '[OK ] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
              else
                FAILED=$((FAILED + 1))
                printf '[FAIL] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
                if [[ -s "${outFile}" ]]; then
                  { printf 'check failed: %s\n' ${lib.escapeShellArg displayName}
                    ${pkgs.coreutils}/bin/cat "${outFile}"
                  } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
                fi
              fi
              ${infoTail}
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
                  url = healthchecksFinalChecksURL;
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
            checkKeyPrefixDescs = {
              "-" = "never fails";
              "+" = "silent on success";
              "!" = "show if details";
            };
            checkKeyPrefixClass =
              let
                keys = lib.attrNames checkKeyPrefixDescs;
              in
              if lib.elem "-" keys then
                "-" + lib.concatStrings (lib.filter (k: k != "-") keys)
              else
                lib.concatStrings keys;
            checkKeyPattern = "[${checkKeyPrefixClass}]?[0-9][0-9] - [a-zA-Z]([ a-zA-Z-]*[a-zA-Z])?";
            invalidKeys = lib.filter (k: builtins.match checkKeyPattern k == null) (lib.attrNames checks);
            checkScripts =
              if invalidKeys == [ ] then
                lib.mapAttrs makeCheckScript checks
              else
                throw "healthchecks (${endpointName}): invalid check key: ${
                  lib.concatStringsSep ", " (map (k: "\"${k}\"") invalidKeys)
                }. Prefixes: ${
                  lib.concatStringsSep ", " (lib.mapAttrsToList (p: d: "\"${p}\" ${d}") checkKeyPrefixDescs)
                }. Example: \"20 - Load\"!";
          in
          pkgs.writeShellScript "nx-hc-${endpointName}" ''
            set -euo pipefail
            TMPDIR_HC=$(${pkgs.coreutils}/bin/mktemp -d)
            trap "${pkgs.coreutils}/bin/rm -rf '$TMPDIR_HC'" EXIT
            export TMPDIR_HC
            REPORT_FILE="$TMPDIR_HC/report"
            DETAIL_FILE="$TMPDIR_HC/detail"
            FAILED=0
            TOTAL=0
            SILENT=0
            _prev_had_info=0
            DETAIL_BUDGET_BYTES=80000
            DETAIL_LINE_BYTES=50
            MIN_DETAIL_LINES=${toString minimalDetailMaxLines}
            MAX_CHECKS=${toString (builtins.length (lib.attrNames checks))}
            if [[ "$MAX_CHECKS" -le 0 ]]; then
              MAX_CHECKS=1
            fi
            DETAIL_MAX_LINES=$((DETAIL_BUDGET_BYTES / DETAIL_LINE_BYTES / MAX_CHECKS))
            if [[ "$DETAIL_MAX_LINES" -lt "$MIN_DETAIL_LINES" ]]; then
              DETAIL_MAX_LINES="$MIN_DETAIL_LINES"
            fi

            ${lib.concatStringsSep "\n" (
              let
                stripSortKey = s: lib.removePrefix "-" (lib.removePrefix "!" (lib.removePrefix "+" s));
                pairs = lib.mapAttrsToList (name: script: { inherit name script; }) checkScripts;
                sorted = lib.sort (a: b: (stripSortKey a.name) < (stripSortKey b.name)) pairs;
              in
              map ({ name, script }: runCheckBlock name script) sorted
            )}

            _silent_sfx=
            if [[ $SILENT -gt 0 ]]; then
              _silent_sfx=" ($SILENT silent)"
            fi
            TOTAL_WITH_SILENT=$((TOTAL + SILENT))
            PASSED=$((TOTAL_WITH_SILENT - FAILED))
            if [[ $FAILED -eq 0 ]]; then
              printf '✓ %d/%d checks are healthy.%s\n' "$TOTAL_WITH_SILENT" "$TOTAL_WITH_SILENT" "$_silent_sfx" > "$REPORT_FILE"
            else
              printf '✗ %d/%d checks are healthy.%s\n' "$PASSED" "$TOTAL_WITH_SILENT" "$_silent_sfx" > "$REPORT_FILE"
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

        secretWipeLineLiterals = [
          "/bin/age"
          "/bin/curl"
          "/bin/git"
          "/bin/gpg"
          "/bin/openssl"
          "/bin/restic"
          "/bin/sops"
          "/bin/ssh"
          "/bin/systemctl"
          "/bin/wg"
          "AGE-SECRET-KEY-1"
          "-----BEGIN"
          "Authorization:"
          "Bearer "
          "passwd"
          "password"
          "/root"
          "/run/secrets"
          "secret"
          "token"
        ];

        secretWipeValueLiterals = [
          "amqp://"
          "amqps://"
          "ftp://"
          "ftps://"
          "http://"
          "https://"
          "mysql://"
          "postgres://"
          "postgresql://"
          "redis://"
          "rediss://"
          "sftp://"
          "smtp://"
          "smtps://"
          "ssh://"
        ];

        secretWipeValueRegexes = [
          "[[:alnum:]_.%+-]+@[[:alnum:].-]+[.][[:alpha:]]{2,}"
          "(^|[^[:alnum:]_])[0-9A-F]{40}([^[:alnum:]_]|$)"
          "(^|[^[:alnum:]_])[0-9A-F]{16}([^[:alnum:]_]|$)"
        ];

        secretReplaceValues = lib.foldl (acc: p: acc // { "${p.key}" = p.val; }) { } (
          lib.filter (p: p.key != null && p.key != "") [
            {
              key = self.host.remote.baseDomain;
              val = "domain";
            }
            {
              key = self.host.hostname;
              val = "hostname";
            }
            {
              key = self.user.username;
              val = "username";
            }
            {
              key = self.user.fullname;
              val = "full name";
            }
            {
              key = self.user.email;
              val = "email";
            }
            {
              key = config.users.users.${mainUser}.home;
              val = "home";
            }
          ]
        );

        makeReplaceToken = label: "<${lib.replaceStrings [ " " ] [ "_" ] (lib.toUpper label)}>";

        escapeAwkRegexLiteral =
          val:
          lib.replaceStrings
            [
              "/"
            ]
            [
              "\\/"
            ]
            (lib.escapeRegex val);

        secretReplaceAwkLines = lib.mapAttrsToList (
          val: lbl: ''gsub(/${escapeAwkRegexLiteral val}/, "${makeReplaceToken lbl}")''
        ) secretReplaceValues;

        secretWipeLineRegex = lib.concatStringsSep "|" (map lib.escapeRegex secretWipeLineLiterals);
        secretWipeValueRegex = lib.concatStringsSep "|" (
          (map lib.escapeRegex secretWipeValueLiterals) ++ secretWipeValueRegexes
        );

        secretCensorScript =
          if !enableSecretReplacements then
            "${pkgs.coreutils}/bin/cat"
          else
            pkgs.writeShellScript "nx-hc-censor" ''
                  ${pkgs.gawk}/bin/awk '
                    BEGIN { IGNORECASE = 1; line_pat = "${secretWipeLineRegex}"; val_pat = "${secretWipeValueRegex}" }
                    ${lib.optionalString (secretReplaceValues != { }) ''
                      {
                        ${lib.concatStringsSep "\n" secretReplaceAwkLines}
                      }
                    ''}
                    match($0, line_pat) {
                  prefix = substr($0, 1, RSTART - 1)
                  suffix = substr($0, RSTART)
                  gsub(/[^ \t]/, "*", suffix)
                  print prefix suffix
                  next
                }
                match($0, val_pat) {
                  prefix = substr($0, 1, RSTART - 1)
                  rest = substr($0, RSTART)
                  if (match(rest, /[ \t]/)) {
                    token = substr(rest, 1, RSTART - 1)
                    tail = substr(rest, RSTART)
                  } else {
                    token = rest
                    tail = ""
                  }
                  gsub(/[^ \t]/, "*", token)
                  print prefix token tail
                  next
                }
                { print }
              '
            '';

        makeCompanionScript =
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
          pkgs.writeShellScript "nx-hc-companion-${endpointName}" ''
            set -euo pipefail
            TMPDIR_HC=$(${pkgs.coreutils}/bin/mktemp -d)
            trap "${pkgs.coreutils}/bin/rm -rf '$TMPDIR_HC'" EXIT
            REPORT_FILE="$TMPDIR_HC/report"
            DETAIL_FILE="$TMPDIR_HC/detail"
            FAILED=0
            TOTAL=0

            while true; do
              _trigger_out=$(${pkgs.systemd}/bin/systemctl show ${lib.escapeShellArg triggerUnit} \
                --property=ActiveState --property=SubState 2>/dev/null || true)
              _trigger_state=$(printf '%s\n' "$_trigger_out" | ${pkgs.gawk}/bin/awk -F= '/^ActiveState=/{print $2}')
              _trigger_substate=$(printf '%s\n' "$_trigger_out" | ${pkgs.gawk}/bin/awk -F= '/^SubState=/{print $2}')
              if [[ "$_trigger_state" != "active" && "$_trigger_state" != "activating" && \
                    "$_trigger_state" != "deactivating" && "$_trigger_state" != "reloading" ]] || \
                 [[ "$_trigger_substate" == "exited" ]]; then
                break
              fi
              ${pkgs.coreutils}/bin/sleep 2
            done

            TOTAL=$((TOTAL + 1))
            _trigger_props=$(${pkgs.systemd}/bin/systemctl show ${lib.escapeShellArg triggerUnit} \
              --property=Result --property=ExecMainCode 2>/dev/null || true)
            TRIGGER_RESULT=$(printf '%s\n' "$_trigger_props" | ${pkgs.gawk}/bin/awk -F= '/^Result=/{print $2}')
            TRIGGER_MAIN_CODE=$(printf '%s\n' "$_trigger_props" | ${pkgs.gawk}/bin/awk -F= '/^ExecMainCode=/{print $2}')
            _trigger_killed=0
            if [[ "$TRIGGER_MAIN_CODE" == "2" || "$TRIGGER_MAIN_CODE" == "3" || \
                  "$TRIGGER_MAIN_CODE" == "killed" || "$TRIGGER_MAIN_CODE" == "dumped" ]]; then
              _trigger_killed=1
            fi
            if [[ "$TRIGGER_RESULT" != "success" ]] || [[ $_trigger_killed -eq 1 ]]; then
              printf '[FAIL] %s (result: %s, code: %s)\n' \
                ${lib.escapeShellArg triggerUnit} "$TRIGGER_RESULT" "$TRIGGER_MAIN_CODE" >> "$DETAIL_FILE"
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
                if [[ -s "$INFO_FILE_CS" ]]; then
                  { printf 'service check details: %s\n' ${lib.escapeShellArg endpointName}
                    ${pkgs.coreutils}/bin/cat "$INFO_FILE_CS"
                  } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
                fi
                FAILED=$((FAILED + 1))
              fi
              if [[ -s "$INFO_FILE_CS" ]]; then
                _info_lines_cs=$(${pkgs.coreutils}/bin/wc -l < "$INFO_FILE_CS")
                DETAIL_BUDGET_BYTES=80000
                DETAIL_LINE_BYTES=50
                MIN_DETAIL_LINES=${toString minimalDetailMaxLines}
                DETAIL_MAX_LINES=$((DETAIL_BUDGET_BYTES / DETAIL_LINE_BYTES))
                if [[ "$DETAIL_MAX_LINES" -lt "$MIN_DETAIL_LINES" ]]; then
                  DETAIL_MAX_LINES="$MIN_DETAIL_LINES"
                fi
                ${pkgs.gnused}/bin/sed 's/^/  /' "$INFO_FILE_CS" \
                  | ${pkgs.coreutils}/bin/head -n "$DETAIL_MAX_LINES" >> "$DETAIL_FILE"
                if [[ "$_info_lines_cs" -gt "$DETAIL_MAX_LINES" ]]; then
                  printf '  [%d lines truncated]\n' "$((_info_lines_cs - DETAIL_MAX_LINES))" >> "$DETAIL_FILE"
                fi
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
              LOG_SINCE=$(${pkgs.systemd}/bin/systemctl show ${lib.escapeShellArg triggerUnit} \
                --property=ExecMainStartTimestamp --value 2>/dev/null || true)
              ${pkgs.systemd}/bin/journalctl -u ${lib.escapeShellArg triggerUnit} \
                ''${LOG_SINCE:+--since "$LOG_SINCE"} \
                --no-pager --output=short -n 500 > "$LOG_FILE" 2>/dev/null || true
              if [[ -s "$LOG_FILE" ]]; then
                FILTERED_LOG="$TMPDIR_HC/service-logs-filtered"
                ${secretCensorScript} < "$LOG_FILE" > "$FILTERED_LOG"
                LOG_HDR=$'\n==== LOGS ====\n\n'
                LOG_HDR_SIZE=''${#LOG_HDR}
                LOG_ELLIPSIS=$'\n[...]\n'
                LOG_ELLIPSIS_SIZE=''${#LOG_ELLIPSIS}
                LOG_FIRST_BYTES=100
                REPORT_SIZE=$(${pkgs.coreutils}/bin/wc -c < "$REPORT_FILE")
                LOG_SIZE=$(${pkgs.coreutils}/bin/wc -c < "$FILTERED_LOG")
                REMAINING=$((100000 - REPORT_SIZE - LOG_HDR_SIZE))
                if [[ $REMAINING -gt 0 ]]; then
                  printf '%s' "$LOG_HDR" >> "$REPORT_FILE"
                  if [[ $LOG_SIZE -le $REMAINING ]]; then
                    ${pkgs.coreutils}/bin/cat "$FILTERED_LOG" >> "$REPORT_FILE"
                  else
                    TAIL_BYTES=$((REMAINING - LOG_FIRST_BYTES - LOG_ELLIPSIS_SIZE))
                    if [[ $TAIL_BYTES -lt 300 ]]; then
                      ${pkgs.coreutils}/bin/tail -c "$REMAINING" "$FILTERED_LOG" >> "$REPORT_FILE"
                    else
                      ${pkgs.coreutils}/bin/head -c "$LOG_FIRST_BYTES" "$FILTERED_LOG" >> "$REPORT_FILE"
                      printf '%s' "$LOG_ELLIPSIS" >> "$REPORT_FILE"
                      ${pkgs.coreutils}/bin/tail -c "$TAIL_BYTES" "$FILTERED_LOG" >> "$REPORT_FILE"
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

        serviceCheckUnits = lib.foldlAttrs (
          acc: key: entry:
          let
            entryName = sanitizeName key;
            endpointName = "${hostname}-${entryName}";
            triggerUnit = entry.trigger.service;
            serviceBaseName = lib.removeSuffix ".service" triggerUnit;
            companionName = "nx-healthchecks-service-${entryName}";
            checkScript = entry.check.checkScript;
            includeLogs = entry.includeLogs;
          in
          acc
          // {
            ${serviceBaseName} = {
              wants = [
                "${companionName}.service"
                "network-online.target"
              ];
              after = [ "network-online.target" ];
              serviceConfig = {
                ExecStartPre = lib.mkBefore [ "+-${makeStartPingScript endpointName}" ];
              };
            };
            ${companionName} = {
              description = "Healthchecks ping for ${triggerUnit}";
              after = [
                triggerUnit
                "network-online.target"
              ];
              wants = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                User = "root";
                TimeoutStartSec = "infinity";
                ExecStart = makeCompanionScript {
                  inherit
                    endpointName
                    triggerUnit
                    checkScript
                    includeLogs
                    ;
                };
              };
            };
          }
        ) { } servicesHealthChecks;

        timedHealthServiceUnits = lib.foldlAttrs (
          acc: key: entry:
          let
            entryName = sanitizeName key;
            endpointName = "${hostname}-${entryName}";
            unitName = "nx-healthchecks-timed-${entryName}";
          in
          acc
          // {
            ${unitName} = {
              description = "Standalone health check ${key}";
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                Type = "oneshot";
                User = "root";
                TimeoutStartSec = entry.timeoutSec;
                SuccessExitStatus = 1;
                ExecStart = makeTimerScript {
                  inherit endpointName;
                  checks = entry.checks;
                  networkTimeoutSec = entry.networkTimeoutSec;
                };
              };
            };
          }
        ) { } timedHealthChecks;

        timedHealthTimerUnits = lib.foldlAttrs (
          acc: key: entry:
          let
            entryName = sanitizeName key;
            unitName = "nx-healthchecks-timed-${entryName}";
            effectiveInterval = if entry.interval != null then entry.interval else "15m";
          in
          acc
          // {
            ${unitName} = {
              description = "Standalone health check timer ${key}";
              wantedBy = [ "timers.target" ];
              timerConfig =
                if entry.schedule != null then
                  {
                    OnCalendar = entry.schedule;
                    Persistent = true;
                    RandomizedDelaySec = entry.randomDelaySec;
                  }
                else
                  {
                    OnBootSec = "5m";
                    OnUnitInactiveSec = effectiveInterval;
                    Persistent = true;
                    RandomizedDelaySec = entry.randomDelaySec;
                  };
            };
          }
        ) { } timedHealthChecks;

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
            {
              assertion = lib.all (entry: entry.checks != { }) (lib.attrValues timedHealthChecks);
              message = "linux.server.healthchecks: timedHealthChecks entries must define at least one check!";
            }
            {
              assertion = lib.all (entry: !(entry.interval != null && entry.schedule != null)) (
                lib.attrValues timedHealthChecks
              );
              message = "linux.server.healthchecks: timedHealthChecks entries cannot define both interval and schedule!";
            }
            {
              assertion = lib.all (entry: entry.interval != null || entry.schedule != null) (
                lib.attrValues timedHealthChecks
              );
              message = "linux.server.healthchecks: timedHealthChecks entries must define either interval or schedule!";
            }
          ];

          sops.secrets."${hostname}-healthchecks-uuid" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "healthchecks-uuid";
            mode = "0400";
            owner = "root";
            group = "root";
          };

          sops.secrets."${hostname}-healthchecks-readonly-api-key" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "healthchecks-readonly-api-key";
            mode = "0400";
            owner = "root";
            group = "root";
          };
        }

        {
          systemd.tmpfiles.settings."10-nx-healthcheck"."/run/nx-healthcheck".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };

          systemd.tmpfiles.settings."10-nx-healthcheck"."${stateDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };

          environment.persistence."${self.persist}" = {
            directories = [ stateDir ];
          };
        }

        {
          systemd.services.nx-healthchecks-shutdown-state = {
            description = "Healthchecks shutdown state marker";
            wantedBy = [ "multi-user.target" ];
            after = [ "local-fs.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "nx-hc-shutdown-state-start" ''
                set -euo pipefail
                if [ -e ${lib.escapeShellArg dirtyMarkerPath} ]; then
                  ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg crashMarkerPath}
                fi
                ${pkgs.coreutils}/bin/touch ${lib.escapeShellArg dirtyMarkerPath}
              '';
              ExecStop = pkgs.writeShellScript "nx-hc-shutdown-state-stop" ''
                set -euo pipefail
                ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg dirtyMarkerPath}
              '';
              NoNewPrivileges = true;
            };
          };
        }

        (lib.mkIf effectiveRegular {
          systemd.services.nx-healthchecks-builtin-regular = {
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

          systemd.timers.nx-healthchecks-builtin-regular = {
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
          systemd.services.nx-healthchecks-builtin-daily = {
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

          systemd.timers.nx-healthchecks-builtin-daily = {
            description = "Daily server health check timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = dailyHealthCheckSchedule;
              Persistent = true;
              RandomizedDelaySec = dailyRandomDelaySec;
            };
          };
        })

        (lib.mkIf effectiveMonthly {
          systemd.services.nx-healthchecks-builtin-monthly = {
            description = "Monthly server health check";
            wants = [ "network-online.target" ];
            after = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              TimeoutStartSec = monthlyServiceTimeoutSec;
              SuccessExitStatus = 1;
              ExecStart = makeTimerScript {
                endpointName = monthlyEndpointName;
                checks = allMonthlyChecks;
                networkTimeoutSec = 900;
              };
            };
          };

          systemd.timers.nx-healthchecks-builtin-monthly = {
            description = "Monthly server health check timer";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = monthlyHealthCheckSchedule;
              Persistent = true;
              RandomizedDelaySec = monthlyRandomDelaySec;
            };
          };
        })

        (lib.mkIf effectiveMonthly {
          systemd.services.nx-healthchecks-builtin-monthly-crash = {
            description = "Monthly health check trigger after unclean previous shutdown";
            wantedBy = [ "multi-user.target" ];
            wants = [ "nx-healthchecks-shutdown-state.service" ];
            after = [ "nx-healthchecks-shutdown-state.service" ];
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              TimeoutStartSec = monthlyServiceTimeoutSec;
              ExecStart = pkgs.writeShellScript "nx-hc-monthly-crash" ''
                set -euo pipefail
                _uptime_sec=$(${pkgs.gawk}/bin/awk '{print int($1)}' /proc/uptime)
                if [[ "$_uptime_sec" -lt 300 ]]; then
                  _wait_sec=$((300 - _uptime_sec))
                  echo "Waiting $_wait_sec seconds for system readiness..."
                  ${pkgs.coreutils}/bin/sleep "$_wait_sec"
                fi
                _today=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)

                if [ ! -e ${lib.escapeShellArg crashMarkerPath} ]; then
                  exit 0
                fi

                if [ -f ${lib.escapeShellArg crashRecoveryDatePath} ] && \
                   [ "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg crashRecoveryDatePath} 2>/dev/null || true)" = "$_today" ]; then
                  exit 0
                fi

                ${pkgs.systemd}/bin/systemctl start --wait nx-healthchecks-builtin-monthly.service
                printf '%s\n' "$_today" > ${lib.escapeShellArg crashRecoveryDatePath}
                ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg crashMarkerPath}
              '';
            };
          };
        })

        (lib.mkIf hasServiceChecks {
          systemd.services = serviceCheckUnits;
        })

        (lib.mkIf hasTimedChecks {
          systemd.services = timedHealthServiceUnits;
          systemd.timers = timedHealthTimerUnits;
        })
      ];
  };
}
