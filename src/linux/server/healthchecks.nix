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
      default = 50;
      description = "Minimum CPU percentage a matching process must consume to activate high-load-exempt mode.";
    };

    highLoadMultiplier = lib.mkOption {
      type = lib.types.float;
      default = 2.7;
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
  };

  module = {
    enabled = config: {
      nx.linux.server.healthchecks.healthchecksFinalChecksURL =
        "${config.nx.linux.server.healthchecks.healthchecksBaseUrl}/projects/${config.nx.linux.server.healthchecks.projectUUID}/checks/";
      nx.linux.server.healthchecks.requireServicesUp = [ "nix-daemon.service" ];
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "nx-healthcheck";
          string = "curl:";
        }
        {
          tag = "systemd";
          service = "init.scope";
          string = "nx-healthcheck-regular.service: Main process exited, code=killed, status=15/TERM";
        }
        {
          tag = "systemd";
          service = "init.scope";
          string = "nx-healthcheck-regular.service: Failed with result 'signal'.";
        }
        {
          tag = "systemd";
          service = "init.scope";
          string = "nx-healthcheck-daily.service: Main process exited, code=killed, status=15/TERM";
        }
        {
          tag = "systemd";
          service = "init.scope";
          string = "nx-healthcheck-daily.service: Failed with result 'signal'.";
        }
      ];
    };

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
        tempMaxCelsius,
        loadMaxPerCore,
        loadBuildMultiplier,
        loadBuildGraceSeconds,
        loadHighCpuExemptCommands,
        requiredCPUForHighLoadDetection,
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
        checkSmartDisk,
        servicesHealthChecks,
        serviceTimeoutSec,
        healthchecksBaseUrl,
        projectUUID,
        healthchecksFinalChecksURL,
        ...
      }:
      let
        hostname = self.host.hostname;
        mainUser = self.host.mainUser.username;
        mainUserUid = toString config.users.users.${self.host.mainUser.username}.uid;
        deploymentMode = config.nx.global.deploymentMode;
        secretPath = config.sops.secrets."${hostname}-healthchecks-uuid".path;

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

        stripGroupPrefix =
          key:
          let
            m = builtins.match ".*-(.*)" key;
          in
          if m != null then lib.trim (builtins.head m) else key;

        makeCheckScript =
          desc: cmd:
          pkgs.writeShellScript "nx-hc-check-${sanitizeName (lib.removePrefix "+" desc)}" ''
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
                printf "%.0f%% mem used, %.0f%% swap used\n", mem_used, swap_used > "/dev/fd/3"
              } else {
                combined_free=(t>0) ? a*100/t : 100
                printf "%.0f%% mem used\n", mem_used > "/dev/fd/3"
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
          if [[ $_zone_count -eq 1 ]]; then
            printf 'core: %dC\n' "$_temp_max" >&3
          else
            for (( _i=0; _i<_zone_count; _i++ )); do
              printf '%s: %dC\n' "''${_zone_names[$_i]}" "''${_zone_temps[$_i]}" >&3
            done
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
                printf "load 5m: %.2f (%s cores, limit: %.1f, mode: %s)\n", load5, nproc, threshold, mode > "/dev/fd/3"
                exit (load5 > threshold)
              }
            ' /proc/loadavg
          '';

        stripProcCmd = pkgs.writeShellScript "nx-hc-strip-proc-cmd" ''
          ${pkgs.gawk}/bin/awk '{
            cmd = $3
            sub(/^\/nix\/store\/[^\/]+\/bin\//, "", cmd)
            sub(/^\/nix\/store\/[^\/]+\//, "", cmd)
            result = cmd
            for (i = 4; i <= NF; i++) {
              arg = $i
              gsub(/\/nix\/store\/[^-]+-/, "..", arg)
              result = result " " arg
            }
            print result
          }'
        '';

        topSnapshotExpr = ''
          ${pkgs.procps}/bin/top -bn2 -d2 2>/dev/null \
            | ${pkgs.gawk}/bin/awk '
                /^top/{b++; next}
                b<2{next}
                /^Tasks|^%Cpu|^MiB|^ *PID/{next}
                NF==0{next}
                $NF=="top"{next}
                {print}
              ' > "$TMPDIR_HC/top-data" || true
          exit 0
        '';

        topCpuExpr = ''
          _n=0
          while IFS= read -r _line; do
            _n=$((_n + 1))
            _pid=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $1}')
            _cpu=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{printf "%5.1f%%", $9}')
            _mem=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{printf "%5.1f%%", $10}')
            _cpu_val=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $9}')
            _mem_val=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $10}')
            _raw=$(${pkgs.coreutils}/bin/tr '\0' ' ' < /proc/"$_pid"/cmdline 2>/dev/null)
            if [[ -n "$_raw" ]]; then
              _cmd=$(printf '%s %s %s' "$_cpu_val" "$_mem_val" "$_raw" | ${stripProcCmd} | ${secretCensorScript})
            else
              _cmd=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $NF}')
            fi
            printf '%d. (cpu=%s, mem=%s): %s\n' "$_n" "$_cpu" "$_mem" "$_cmd" >&3
          done < <(${pkgs.gawk}/bin/awk '$9+0<0.1{next} {print}' "$TMPDIR_HC/top-data" 2>/dev/null \
            | ${pkgs.coreutils}/bin/head -5) || true
          if [[ $_n -eq 0 ]]; then
            printf '   [no process above 0.1%% cpu]\n' >&3
          fi
          exit 0
        '';

        topMemExpr = ''
          _n=0
          while IFS= read -r _line; do
            _n=$((_n + 1))
            _pid=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $1}')
            _cpu=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{printf "%5.1f%%", $9}')
            _mem=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{printf "%5.1f%%", $10}')
            _cpu_val=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $9}')
            _mem_val=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $10}')
            _raw=$(${pkgs.coreutils}/bin/tr '\0' ' ' < /proc/"$_pid"/cmdline 2>/dev/null)
            if [[ -n "$_raw" ]]; then
              _cmd=$(printf '%s %s %s' "$_cpu_val" "$_mem_val" "$_raw" | ${stripProcCmd} | ${secretCensorScript})
            else
              _cmd=$(printf '%s' "$_line" | ${pkgs.gawk}/bin/awk '{print $NF}')
            fi
            printf '%d. (cpu=%s, mem=%s): %s\n' "$_n" "$_cpu" "$_mem" "$_cmd" >&3
          done < <(${pkgs.gawk}/bin/awk '$10+0<0.1{next} {print}' "$TMPDIR_HC/top-data" 2>/dev/null \
            | ${pkgs.coreutils}/bin/sort -rn -k10 \
            | ${pkgs.coreutils}/bin/head -5) || true
          if [[ $_n -eq 0 ]]; then
            printf '   [no process above 0.1%% mem]\n' >&3
          fi
          exit 0
        '';

        allRegularChecks = {
          "+00 - Process snapshot" = topSnapshotExpr;
          "10 - Server is up" = "true";
          "40 - System services health" = ''
            _failed=$(${pkgs.systemd}/bin/systemctl --failed --plain --no-legend --no-pager 2>/dev/null \
              | ${pkgs.gawk}/bin/awk 'NF>0{print $1}')
            if [[ -n "$_failed" ]]; then
              printf '%s\n' "$_failed" >&3
              exit 1
            fi
          '';
          "40 - User services health" = ''
            ${pkgs.systemd}/bin/systemctl is-active --quiet "user@${mainUserUid}.service" 2>/dev/null || exit 0
            _failed=$(${pkgs.systemd}/bin/systemctl --user --failed --plain --no-legend --no-pager \
              --machine=${mainUser}@.host 2>/dev/null \
              | ${pkgs.gawk}/bin/awk 'NF>0{print $1}')
            if [[ -n "$_failed" ]]; then
              printf '%s\n' "$_failed" >&3
              exit 1
            fi
          '';
          "20 - Memory and swap free" = memoryCheckExpr;
        }
        // lib.optionalAttrs (!self.isVirtual) { "20 - Temperature" = thermalCheckExpr; }
        // {
          "20 - Load" = loadCheckExpr;
        }
        // lib.optionalAttrs (requireServicesUp != [ ]) { "50 - Required services" = servicesGroupedExpr; }
        // {
          "60 - Top CPU processes" = topCpuExpr;
          "60 - Top memory processes" = topMemExpr;
        }
        // regularHealthChecks;

        allDailyChecks =
          lib.optionalAttrs checkDiskUsage { "10 - Disk space" = diskUsageExpr; }
          // lib.optionalAttrs checkCertExpiry { "20 - Certificate expiry" = certExpiryExpr; }
          // lib.optionalAttrs (checkSmartDisk && config.nx.linux.storage.smartd.enable) {
            "30 - SMART disk health" = smartDiskExpr;
          }
          // dailyHealthChecks;

        runCheckBlock =
          desc: script:
          let
            silent = lib.hasPrefix "+" desc;
            cleanDesc = if silent then lib.removePrefix "+" desc else desc;
            infoFile = "$TMPDIR_HC/info-${sanitizeName cleanDesc}";
            outFile = "$TMPDIR_HC/out-${sanitizeName cleanDesc}";
            displayName = stripGroupPrefix cleanDesc;
          in
          if silent then
            ''
              if ! ${script} 3>"${infoFile}" >"${outFile}" 2>&1; then
                TOTAL=$((TOTAL + 1))
                FAILED=$((FAILED + 1))
                if [[ $_prev_had_info -eq 1 ]]; then
                  printf '\n' >> "$DETAIL_FILE"
                fi
                printf '[FAIL] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
                if [[ -s "${outFile}" ]]; then
                  { printf 'check failed: %s\n' ${lib.escapeShellArg displayName}
                    ${pkgs.coreutils}/bin/cat "${outFile}"
                  } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
                fi
                if [[ -s "${infoFile}" ]]; then
                  _prev_had_info=1
                  ${pkgs.gnused}/bin/sed 's/^/  /' "${infoFile}" \
                    | ${pkgs.coreutils}/bin/head -10 >> "$DETAIL_FILE"
                else
                  _prev_had_info=0
                fi
              fi
            ''
          else
            ''
              if [[ $_prev_had_info -eq 1 ]]; then
                printf '\n' >> "$DETAIL_FILE"
              fi
              TOTAL=$((TOTAL + 1))
              if ${script} 3>"${infoFile}" >"${outFile}" 2>&1; then
                printf '[OK ] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
              else
                printf '[FAIL] %s\n' ${lib.escapeShellArg displayName} >> "$DETAIL_FILE"
                if [[ -s "${outFile}" ]]; then
                  { printf 'check failed: %s\n' ${lib.escapeShellArg displayName}
                    ${pkgs.coreutils}/bin/cat "${outFile}"
                  } | ${pkgs.systemd}/bin/systemd-cat -t nx-healthcheck -p err
                fi
                FAILED=$((FAILED + 1))
              fi
              if [[ -s "${infoFile}" ]]; then
                _prev_had_info=1
                ${pkgs.gnused}/bin/sed 's/^/  /' "${infoFile}" \
                  | ${pkgs.coreutils}/bin/head -10 >> "$DETAIL_FILE"
              else
                _prev_had_info=0
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
            _prev_had_info=0

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
          config.users.users.${mainUser}.home
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
          "[[:alnum:]_.%+-]+@[[:alnum:].-]+\\.[[:alpha:]]{2,}"
          "\\<[0-9A-F]{40}\\>"
          "\\<[0-9A-F]{16}\\>"
        ];

        secretWipeLineRegex = lib.concatStringsSep "|" (map lib.escapeRegex secretWipeLineLiterals);
        secretWipeValueRegex = lib.concatStringsSep "|" (
          (map lib.escapeRegex secretWipeValueLiterals) ++ secretWipeValueRegexes
        );

        secretCensorScript = pkgs.writeShellScript "nx-hc-censor" ''
          ${pkgs.gawk}/bin/awk '
            BEGIN { IGNORECASE = 1; line_pat = "${secretWipeLineRegex}"; val_pat = "${secretWipeValueRegex}" }
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
            companionName = "nx-hc-${entryName}";
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

        {
          systemd.tmpfiles.settings."10-nx-healthcheck"."/run/nx-healthcheck".d = {
            mode = "0700";
            user = "root";
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
