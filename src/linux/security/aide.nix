args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  defaultDbDir = "/var/lib/aide";
  confPath = "/etc/aide/aide.conf";
  linkTargetsPath = "/etc/aide/link-targets";
  fstatFilterPath = "/etc/aide/fstat-filter";
  fstatFilterRegexPath = "/etc/aide/fstat-filter-regex";
  oneshotUnit = "nx-healthchecks-oneshot-aide-check.service";
  aideBin = "${pkgs.aide}/bin/aide";
  stateDir = "/var/lib/nx-aide";
  postBootMarker = "${stateDir}/pending-post-boot-commit";
  logDir = "/var/log/aide";
  dedupStateFile = "${logDir}/last-failure-state";
  lockDir = "/run/nx-aide";
  lockFile = "${lockDir}/aide.lock";
  lockWaitSec = 600;

  acquireLock =
    {
      failMessage,
      exitCode ? 1,
    }:
    ''
      exec {aide_lock_fd}>${lockFile}
      if ! ${pkgs.util-linux}/bin/flock -w ${toString lockWaitSec} "$aide_lock_fd"; then
        ${failMessage}
        exit ${toString exitCode}
      fi
    '';

  resolvePath = path: if lib.hasPrefix "/" path then path else "${self.user.home}/${path}";

  resolveRegex =
    pattern:
    if lib.hasPrefix "/" pattern then pattern else "${lib.escapeRegex self.user.home}/${pattern}";

  rootGuard = name: ''
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "0" ]; then
      echo "${name} must be run as root!" >&2
      exit 1
    fi
  '';

  failHighlightPattern = service: title: message: {
    inherit service;
    string = "AIDE integrity check FAILED";
    active = "always";
    extract = "AIDE integrity check FAILED: (?P<reason>.+)";
    mapping = {
      label = "AIDE";
      inherit title;
      icon = "dialog-warning";
      priority = "warn";
      inherit message;
    };
  };

  markerOlderThanBoot = ''
    marker_pending=0
    if [ -e ${postBootMarker} ]; then
      _btime=$(${pkgs.gawk}/bin/awk '/^btime/{print $2}' /proc/stat)
      _marker_mtime=$(${pkgs.coreutils}/bin/stat -c %Y ${postBootMarker})
      if [ "$_marker_mtime" -lt "$_btime" ]; then
        marker_pending=1
      fi
    fi
  '';

  clearStaleMarker = ''
    ${markerOlderThanBoot}
    if [ "$marker_pending" = "1" ]; then
      ${pkgs.coreutils}/bin/rm -f ${postBootMarker}
      echo "Stale AIDE post-boot marker cleared"
    fi
  '';

  fstatFilterScript = pkgs.writeShellScript "nx-aide-fstat-filter" ''
    set -uo pipefail
    _src="$1"
    _tmp=$(${pkgs.coreutils}/bin/mktemp -d)
    trap '${pkgs.coreutils}/bin/rm -rf "$_tmp"' EXIT
    : > "$_tmp/lit"
    : > "$_tmp/rx"
    if [ -s ${fstatFilterPath} ]; then
      ${pkgs.gnused}/bin/sed 's#.*#fstat() failed for &: #' ${fstatFilterPath} > "$_tmp/lit"
    fi
    if [ -s ${fstatFilterRegexPath} ]; then
      ${pkgs.gnused}/bin/sed 's#^#fstat\\(\\) failed for #' ${fstatFilterRegexPath} > "$_tmp/rx"
    fi
    ${pkgs.gnugrep}/bin/grep -vFf "$_tmp/lit" "$_src" 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep -vEf "$_tmp/rx" > "$_tmp/out" 2>/dev/null || true
    if [ ! -s "$_tmp/out" ] && [ -s "$_src" ]; then
      ${pkgs.coreutils}/bin/cat "$_src"
    else
      ${pkgs.coreutils}/bin/cat "$_tmp/out"
    fi
  '';

  mkCheckCoreScript =
    { dbDir }:
    pkgs.writeShellScript "nx-aide-check-core" ''
      set -uo pipefail
      ${acquireLock {
        failMessage = ''echo "AIDE integrity check FAILED: Could not acquire AIDE lock for check within ${toString lockWaitSec} seconds"'';
        exitCode = 9;
      }}
      dedup="''${NX_AIDE_DEDUP:-0}"
      tmpdir=$(${pkgs.coreutils}/bin/mktemp -d)
      trap '${pkgs.coreutils}/bin/rm -rf "$tmpdir"' EXIT
      failfile="$tmpdir/failures"
      : > "$failfile"
      link_status=0
      if [ -f ${linkTargetsPath} ]; then
        while IFS='|' read -r lpath ltarget lfinal; do
          [ -n "$lpath" ] || continue
          ltarget_actual="$(${pkgs.coreutils}/bin/readlink "$lpath" || echo "(missing)")"
          if [ -n "$ltarget" ]; then
            if [ "$ltarget_actual" != "$ltarget" ]; then
              echo "AIDE integrity check FAILED: Link target mismatch for $lpath" >> "$failfile"
              link_status=1
            fi
          else
            case "$ltarget_actual" in
            /nix/store/*) ;;
            *)
              echo "AIDE integrity check FAILED: Link target outside the nix store for $lpath" >> "$failfile"
              link_status=1
              ;;
            esac
          fi
          if [ -n "$lfinal" ] && [ "$(${pkgs.coreutils}/bin/readlink -f "$lpath" || echo "(missing)")" != "$lfinal" ]; then
            echo "AIDE integrity check FAILED: Resolved target mismatch for $lpath" >> "$failfile"
            link_status=1
          fi
        done < ${linkTargetsPath}
      fi
      ${markerOlderThanBoot}
      if [ "$marker_pending" = "1" ]; then
        ${pkgs.coreutils}/bin/cat "$failfile"
        echo "AIDE integrity check skipped, pending post boot commit"
        exit "$link_status"
      fi
      if [ ! -f ${dbDir}/active/aide.db ]; then
        echo "AIDE database missing, initializing baseline"
        ${aideBin} --init --config ${confPath} || true
        if [ -f ${dbDir}/aide.db.new ]; then
          ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${dbDir}/active
          ${pkgs.coreutils}/bin/mv ${dbDir}/aide.db.new ${dbDir}/active/aide.db
          echo "AIDE database initialized at ${dbDir}/active/aide.db"
          exit "$link_status"
        fi
        echo "AIDE integrity check FAILED: Database initialization failed"
        exit 1
      fi
      status=0
      ${aideBin} --check --config ${confPath} > "$tmpdir/aide-raw" 2>&1 || status=$?
      ${fstatFilterScript} "$tmpdir/aide-raw" > "$tmpdir/aide-out"
      if [ -d ${logDir} ]; then
        _logf="${logDir}/check-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).log"
        ${pkgs.coreutils}/bin/cat "$failfile" "$tmpdir/aide-out" > "$_logf" 2>/dev/null || true
        ${pkgs.coreutils}/bin/chgrp "$(${pkgs.coreutils}/bin/id -gn ${self.user.username})" "$_logf" 2>/dev/null || true
        ${pkgs.coreutils}/bin/chmod 0640 "$_logf" 2>/dev/null || true
      fi
      ${pkgs.coreutils}/bin/cat "$tmpdir/aide-out"
      if [ "$status" -eq 0 ] && [ "$link_status" -eq 0 ]; then
        ${pkgs.coreutils}/bin/rm -f ${dedupStateFile}
        echo "AIDE integrity check OK"
        exit 0
      fi
      ${pkgs.gawk}/bin/awk '/^Start timestamp:/{flag=1;next} /^End timestamp:/{flag=0} flag' "$tmpdir/aide-out" > "$tmpdir/section"
      ${pkgs.coreutils}/bin/cat "$failfile" "$tmpdir/section" > "$tmpdir/state"
      if [ "$dedup" = "1" ] && [ -f ${dedupStateFile} ] && ${pkgs.diffutils}/bin/cmp -s "$tmpdir/state" ${dedupStateFile}; then
        echo "AIDE integrity check still failing, unchanged since the last notification"
      else
        ${pkgs.coreutils}/bin/cp "$tmpdir/state" ${dedupStateFile} || true
        ${pkgs.coreutils}/bin/cat "$failfile"
        if [ "$status" -gt 7 ]; then
          echo "AIDE integrity check FAILED: Error (status $status)"
        elif [ "$status" -ge 1 ]; then
          _changes=""
          [ $((status & 1)) -ne 0 ] && _changes="added"
          [ $((status & 2)) -ne 0 ] && _changes="''${_changes:+$_changes, }removed"
          [ $((status & 4)) -ne 0 ] && _changes="''${_changes:+$_changes, }changed"
          echo "AIDE integrity check FAILED: ''${_changes^} entries detected"
        fi
      fi
      if [ "$status" -gt 0 ]; then
        exit "$status"
      fi
      exit "$link_status"
    '';

  checkCoreScript = config: mkCheckCoreScript { dbDir = config.nx.linux.security.aide.dbDir; };

  hcCheckScript =
    config:
    pkgs.writeShellScript "nx-aide-hc-check" ''
      _out=$(${checkCoreScript config} 2>&1)
      _st=$?
      if [ "$_st" -ne 0 ]; then
        printf '%s\n' "$_out" >&3
      fi
      exit "$_st"
    '';

  mkInitScript =
    { dbDir, hcEnabled }:
    pkgs.writeShellScriptBin "aide-init" ''
      set -euo pipefail
      ${rootGuard "aide-init"}
      if [ -f ${dbDir}/active/aide.db ]; then
        printf '%s' "AIDE database ${dbDir}/active/aide.db already exists, reinitialize the baseline? [y/N] "
        IFS= read -r _answer || _answer=""
        if [ "$_answer" != "y" ]; then
          echo "Keeping the existing database"
          exit 1
        fi
      fi
      ${acquireLock {
        failMessage = ''echo "AIDE integrity check FAILED: Could not acquire AIDE lock for init within ${toString lockWaitSec} seconds" >&2'';
      }}
      ${aideBin} --init --config ${confPath}
      ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${dbDir}/active
      ${pkgs.coreutils}/bin/mv ${dbDir}/aide.db.new ${dbDir}/active/aide.db
      echo "AIDE database initialized at ${dbDir}/active/aide.db"
      ${lib.optionalString hcEnabled ''
        ${pkgs.systemd}/bin/systemctl start --no-block ${oneshotUnit}
        echo "Verification check with healthchecks ping started in the background"
      ''}
    '';

  mkCheckScript =
    { config, hcEnabled }:
    pkgs.writeShellScriptBin "aide-check" (
      if hcEnabled then
        ''
          set -euo pipefail
          ${rootGuard "aide-check"}
          _start=$(${pkgs.coreutils}/bin/date +%s)
          ${pkgs.systemd}/bin/systemctl start ${oneshotUnit} || true
          _journal=$(${pkgs.systemd}/bin/journalctl -u ${oneshotUnit} --since "@''${_start}" --no-pager)
          printf '%s\n' "$_journal"
          if printf '%s' "$_journal" | ${pkgs.gnugrep}/bin/grep -qF "AIDE integrity check FAILED"; then
            exit 1
          fi
        ''
      else
        ''
          set -uo pipefail
          ${rootGuard "aide-check"}
          exec ${checkCoreScript config}
        ''
    );

  mkCommitScript =
    { dbDir, hcEnabled }:
    pkgs.writeShellScriptBin "aide-commit" (
      ''
        set -euo pipefail
        ${rootGuard "aide-commit"}
      ''
      + "exec ${pkgs.systemd}/bin/systemd-inhibit --who=\"aide-commit\" --what=\"idle:sleep:shutdown\" --why=\"AIDE database update in progress\" "
      + pkgs.writeShellScript "aide-commit-main" ''
        set -euo pipefail
        ${acquireLock {
          failMessage = ''echo "AIDE integrity check FAILED: Could not acquire AIDE lock for commit within ${toString lockWaitSec} seconds" >&2'';
        }}
        force=0
        if [ "''${1:-}" = "--force" ]; then
          force=1
        fi
        logfile=/dev/null
        if [ -d ${logDir} ]; then
          logfile="${logDir}/commit-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).log"
        fi
        _raw=$(${pkgs.coreutils}/bin/mktemp)
        trap '${pkgs.coreutils}/bin/rm -f "$_raw"' EXIT
        if [ ! -f ${dbDir}/active/aide.db ]; then
          echo "AIDE database missing, initializing baseline"
          ${aideBin} --init --config ${confPath} > "$_raw" 2>&1 || true
          ${fstatFilterScript} "$_raw" | ${pkgs.coreutils}/bin/tee "$logfile" || true
          if [ -f "$logfile" ]; then
            ${pkgs.coreutils}/bin/chgrp "$(${pkgs.coreutils}/bin/id -gn ${self.user.username})" "$logfile" 2>/dev/null || true
            ${pkgs.coreutils}/bin/chmod 0640 "$logfile" 2>/dev/null || true
          fi
          if [ ! -f ${dbDir}/aide.db.new ]; then
            echo "AIDE integrity check FAILED: Database initialization failed" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${dbDir}/active
          ${pkgs.coreutils}/bin/mv ${dbDir}/aide.db.new ${dbDir}/active/aide.db
          echo "AIDE database initialized at ${dbDir}/active/aide.db"
          ${lib.optionalString hcEnabled ''
            ${pkgs.systemd}/bin/systemctl start --no-block ${oneshotUnit}
          ''}
          ${clearStaleMarker}
          exit 0
        fi
        status=0
        ${aideBin} --update --config ${confPath} > "$_raw" 2>&1 || status=$?
        ${fstatFilterScript} "$_raw" | ${pkgs.coreutils}/bin/tee "$logfile" || true
        if [ -f "$logfile" ]; then
          ${pkgs.coreutils}/bin/chgrp "$(${pkgs.coreutils}/bin/id -gn ${self.user.username})" "$logfile" 2>/dev/null || true
          ${pkgs.coreutils}/bin/chmod 0640 "$logfile" 2>/dev/null || true
        fi
        if [ "$status" -gt 7 ]; then
          echo "AIDE integrity check FAILED: Update failed with status $status" >&2
          exit "$status"
        fi
        if [ ! -f ${dbDir}/aide.db.new ]; then
          echo "AIDE integrity check FAILED: Update did not produce a new database" >&2
          exit 1
        fi
        if [ "$force" != "1" ] && [ "$status" != "0" ]; then
          ${pkgs.coreutils}/bin/rm -f ${dbDir}/aide.db.new
          echo "AIDE integrity check FAILED: Changes detected, database not updated, run aide-commit --force to accept them" >&2
          exit "$status"
        fi
        if [ "$status" = "0" ]; then
          ${pkgs.coreutils}/bin/rm -f ${dbDir}/aide.db.new
          echo "AIDE found no differences, database left unchanged"
        else
          ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${dbDir}/active
          ${pkgs.coreutils}/bin/mv ${dbDir}/aide.db.new ${dbDir}/active/aide.db
          echo "AIDE database updated at ${dbDir}/active/aide.db"
        fi
        ${clearStaleMarker}
        ${lib.optionalString hcEnabled ''
          ${pkgs.systemd}/bin/systemctl start --no-block ${oneshotUnit}
          echo "Success ping check started in the background"
        ''}
      ''
      + " \"$@\""
    );

  mkPostBootCommitScript =
    commitBin:
    pkgs.writeShellScript "nx-aide-post-boot-commit" ''
      set -euo pipefail
      ${markerOlderThanBoot}
      if [ "$marker_pending" != "1" ]; then
        exit 0
      fi
      ${commitBin}/bin/aide-commit --force
    '';
in
{
  name = "aide";
  description = "AIDE file integrity monitoring";

  group = "security";
  input = "linux";

  submodules = {
    linux.security.auditd = true;
  };

  options = {
    schedule = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "OnCalendar schedule for the AIDE check, null auto-selects by deployment mode.";
    };
    serverSchedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* *:00:00";
      description = "OnCalendar schedule for server and managed deployment modes.";
    };
    desktopSchedule = lib.mkOption {
      type = lib.types.str;
      default = "*:0/15";
      description = "OnCalendar schedule for local and develop deployment modes.";
    };
    randomDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 120;
      description = "RandomizedDelaySec for the AIDE check timer in seconds.";
    };
    dbDir = lib.mkOption {
      type = lib.types.str;
      default = defaultDbDir;
      description = "Directory holding the AIDE databases.";
    };
    checkTimeoutSec = lib.mkOption {
      type = lib.types.int;
      default = 1800;
      description = "TimeoutStartSec for the AIDE check service in seconds.";
    };
    logRetentionDays = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "Days to keep AIDE check and commit logs before tmpfiles cleanup removes them.";
    };
    testingMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run AIDE without healthchecks, notification and upgrade integration, logging results to the journal only.";
    };
    healthchecksUUID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Healthchecks.io UUID of the AIDE check, used for the dashboard card when the dashboard is enabled.";
    };
    fullRuleset = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Enable the full high-churn ruleset, null auto-enables it in server and managed deployment modes.";
    };
    skipPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths pruned entirely from AIDE scanning without traversal.";
    };
    skipPathsRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns pruned entirely from AIDE scanning without traversal.";
    };
    excludePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths excluded from AIDE scanning while their parents are still traversed.";
    };
    excludePathsRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns excluded from AIDE scanning while their parents are still traversed.";
    };
    directoryChecks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Directories checked as inode-only skeleton entries without recursion.";
    };
    directoryChecksRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns for directories checked as inode-only skeleton entries without recursion.";
    };
    fileChecks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Files watched with content hashing as anchored entries.";
    };
    fileChecksRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns for files watched with content hashing as anchored entries.";
    };
    directoryWatches = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Directory trees watched recursively with content hashing including inode.";
    };
    directoryWatchesRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns for directory trees watched recursively with content hashing including inode.";
    };
    contentDirectoryWatches = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Directory trees watched recursively with content hashing without inode, for inode-churning trees.";
    };
    contentDirectoryWatchesRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns for directory trees watched recursively with content hashing without inode.";
    };
    permsChecks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Paths watched with permissions and ownership metadata only.";
    };
    permsChecksRegex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Regex patterns watched with permissions and ownership metadata only.";
    };
    linkTargets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Symlink paths mapped to their expected direct targets, an empty target only requires a nix store target.";
    };
    configLines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Raw AIDE config lines appended at the end of the generated config.";
    };
  };

  module = {
    enabled = config: {
      nx.global.aideEnabled = true;
      nx.global.aidePostBootMarker =
        if !config.nx.linux.security.aide.testingMode then postBootMarker else null;
      nx.lib.icons = [
        "checkmark"
        "dialog-error"
        "dialog-warning"
      ];
      nx.linux.monitoring.journal-watcher.highlightPatterns =
        let
          hcEnabled = config.nx.linux.server.healthchecks.enable;
          testingMode = config.nx.linux.security.aide.testingMode;
        in
        lib.optional (!testingMode && !hcEnabled) (
          failHighlightPattern "nx-aide-check.service" "AIDE Check Failed" "{reason}"
        )
        ++ lib.optional (!testingMode) (
          failHighlightPattern "nx-aide-check-boot.service" "AIDE Boot Check" "{reason}"
        )
        ++ lib.optional (!testingMode) (
          failHighlightPattern "nx-aide-post-boot-commit.service" "AIDE Post-Boot Commit Failed" "{reason}"
        );
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "systemd-inhibit";
          string = "aide-commit-main failed with exit status";
          unitless = true;
        }
        {
          service = "auditd.service";
          tag = "audisp-syslog";
          string = ''comm="(chmod|chown)".*key="aide_db"'';
        }
      ];
    };

    ifEnabled.linux.security.auditd.enabled = config: {
      nx.linux.security.auditd.dirContentWatches.aide_db =
        "!${config.nx.linux.security.aide.dbDir}/active";
      nx.linux.security.auditd.dirContentWatches.aide_state = stateDir;
      nx.linux.security.auditd.dirContentWatches.aide_config = "${builtins.dirOf confPath}";
    };

    ifEnabled.linux.server.healthchecks.enabled =
      config:
      lib.mkIf (!config.nx.linux.security.aide.testingMode) {
        nx.linux.server.healthchecks.servicesHealthChecks."aide-check" = {
          trigger.service = "nx-aide-check.service";
          includeLogs = true;
          displayName = "AIDE Integrity";
          icon = "security-onion";
          uuid = config.nx.linux.security.aide.healthchecksUUID;
        };
        nx.linux.server.healthchecks.oneshotHealthChecks."aide-check" = {
          checks."+50 - AIDE integrity" = "${hcCheckScript config}";
        };
      };

    ifEnabled.linux.system.auto-upgrades = {
      enabled =
        config:
        lib.mkIf (!config.nx.linux.security.aide.testingMode) {
          nx.linux.monitoring.journal-watcher.highlightPatterns = [
            (failHighlightPattern "nx-auto-upgrade.service" "Upgrade Aborted" "Upgrade aborted: {reason}")
          ];
        };

      system =
        config:
        lib.mkIf (!config.nx.linux.security.aide.testingMode) {
          systemd.services.nx-auto-upgrade.serviceConfig = {
            ExecStartPre = lib.mkBefore [ "+${checkCoreScript config}" ];
            ExecStartPost = [
              "+${pkgs.coreutils}/bin/touch ${postBootMarker}"
              "+${
                mkCommitScript {
                  dbDir = config.nx.linux.security.aide.dbDir;
                  hcEnabled = config.nx.linux.server.healthchecks.enable;
                }
              }/bin/aide-commit --force"
            ];
          };
        };
    };

    ifEnabled.linux.desktop.niri.home =
      config:
      let
        terminal = config.nx.preferences.desktop.programs.additionalTerminal;
        terminalRunWithClass =
          class: cmd:
          lib.escapeShellArgs (
            helpers.runWithAbsolutePath config terminal (terminal.openRunWithClass class) cmd
          );
      in
      {
        programs.niri = {
          settings = {
            binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+A" = {
                action = spawn-sh (terminalRunWithClass "org.nx.aide-log" "aide-log-view");
                hotkey-overlay.title = "System:AIDE last log";
              };
            };

            window-rules = [
              {
                matches = [ { app-id = "org.nx.aide-log"; } ];
                open-floating = true;
                open-focused = true;
                block-out-from = "screencast";
              }
            ];
          };
        };
      };

    linux.integrated =
      config:
      let
        isHeadless = (self.host.settings.system.desktop or null) == null;
        iconPath = "${helpers.packageFile args config.nx.linux.desktop.icons.dashboardIcons
          "svg/security-onion.svg"
        }";
        mkCommitTriggerText =
          {
            forceArg,
            failTitle,
            failBody,
            failUrgency,
          }:
          ''
            #!/usr/bin/env bash
            set -uo pipefail
            if [ "$(${pkgs.coreutils}/bin/id -u)" != "0" ]; then
              echo "Must be run as root!" >&2
              exit 1
            fi
            status=0
            /run/current-system/sw/bin/aide-commit${forceArg} || status=$?
            if [ "$status" = "0" ]; then
              ${self.notifyUser {
                inherit pkgs;
                title = "AIDE Commit";
                body = "AIDE database updated successfully";
                icon = "checkmark";
                urgency = "normal";
                validation = { inherit config; };
              }}
            else
              ${self.notifyUser {
                inherit pkgs;
                title = failTitle;
                body = failBody;
                icon = "dialog-error";
                urgency = failUrgency;
                validation = { inherit config; };
              }}
            fi
            exit "$status"
          '';
        mkGuiWrapperText = target: ''
          #!/usr/bin/env bash
          set -euo pipefail
          exec pkexec ${self.binDir}/${target}
        '';
      in
      {
        home.file = {
          "${defs.binDir}/aide-log-view" = {
            text = ''
              #!/usr/bin/env bash
              set -uo pipefail
              log=$(ls -1t ${logDir}/*.log 2>/dev/null | head -n 1)
              if [ -z "''${log:-}" ]; then
                echo "No AIDE logs found in ${logDir}"
              else
                echo "=== ''${log} ==="
                echo
                awk '
                  { lines[NR] = $0 }
                  /^The attributes of the \(uncompressed\) database\(s\):$/ { last = NR - 1; done = 1; exit }
                  END {
                    if (!done) last = NR
                    while (last > 0 && (lines[last] ~ /^-+$/ || lines[last] ~ /^[[:space:]]*$/)) last--
                    for (i = 1; i <= last; i++) print lines[i]
                  }
                ' "$log"
                echo
                case "''${log##*/}" in
                commit-*)
                  echo "+++ COMMIT log +++"
                  ;;
                check-*)
                  echo "--- CHECK log ---"
                  ;;
                esac
              fi
              echo
              echo "Press any key to exit..."
              read -n 1
            '';
            executable = true;
          };
        }
        // lib.optionalAttrs (!isHeadless) {
          "${defs.binDir}/aide-commit-trigger-manually" = {
            text = mkCommitTriggerText {
              forceArg = "";
              failTitle = "AIDE Commit";
              failBody = "Changes detected, run AIDE: Commit database (force) to accept them";
              failUrgency = "normal";
            };
            executable = true;
          };
          "${defs.binDir}/aide-commit-trigger-manually-gui" = {
            text = mkGuiWrapperText "aide-commit-trigger-manually";
            executable = true;
          };
          "${defs.binDir}/aide-commit-trigger-manually-force" = {
            text = mkCommitTriggerText {
              forceArg = " --force";
              failTitle = "AIDE Commit Failed";
              failBody = "aide-commit exited with status $status";
              failUrgency = "critical";
            };
            executable = true;
          };
          "${defs.binDir}/aide-commit-trigger-manually-force-gui" = {
            text = mkGuiWrapperText "aide-commit-trigger-manually-force";
            executable = true;
          };
        };
      }
      // lib.optionalAttrs (!isHeadless) {
        xdg.desktopEntries.aide-commit-trigger = {
          name = "AIDE: Commit database";
          comment = "Commit pending AIDE integrity changes when the baseline is clean";
          exec = "${self.binDir}/aide-commit-trigger-manually-gui";
          icon = iconPath;
          terminal = false;
          categories = [ "System" ];
        };
        xdg.desktopEntries.aide-commit-trigger-force = {
          name = "AIDE: Commit database (force)";
          comment = "Accept and commit pending AIDE integrity changes";
          exec = "${self.binDir}/aide-commit-trigger-manually-force-gui";
          icon = iconPath;
          terminal = false;
          categories = [ "System" ];
        };
      };

    linux.system =
      {
        config,
        schedule,
        serverSchedule,
        desktopSchedule,
        randomDelaySec,
        dbDir,
        checkTimeoutSec,
        logRetentionDays,
        testingMode,
        fullRuleset,
        skipPaths,
        skipPathsRegex,
        excludePaths,
        excludePathsRegex,
        directoryChecks,
        directoryChecksRegex,
        fileChecks,
        fileChecksRegex,
        directoryWatches,
        directoryWatchesRegex,
        contentDirectoryWatches,
        contentDirectoryWatchesRegex,
        permsChecks,
        permsChecksRegex,
        linkTargets,
        configLines,
        ...
      }:
      let
        hcEnabled = config.nx.linux.server.healthchecks.enable && !testingMode;
        serverMode = helpers.isDeploymentMode self [
          "server"
          "managed"
        ];
        isHeadless = (self.host.settings.system.desktop or null) == null;
        userGroup = config.users.users.${self.user.username}.group;

        effectiveFullRuleset = if fullRuleset != null then fullRuleset else serverMode;
        effectiveSchedule =
          if schedule != null then
            schedule
          else if serverMode then
            serverSchedule
          else
            desktopSchedule;

        commitBin = mkCommitScript { inherit dbDir hcEnabled; };

        resolvedSkipPaths = map resolvePath skipPaths;
        resolvedSkipPathsRegex = map resolveRegex skipPathsRegex;
        resolvedExcludePaths = map resolvePath excludePaths;
        resolvedExcludePathsRegex = map resolveRegex excludePathsRegex;
        resolvedDirectoryChecks = map resolvePath directoryChecks;
        resolvedDirectoryChecksRegex = map resolveRegex directoryChecksRegex;
        resolvedFileChecks = map resolvePath fileChecks;
        resolvedFileChecksRegex = map resolveRegex fileChecksRegex;
        resolvedDirectoryWatches = map resolvePath directoryWatches;
        resolvedDirectoryWatchesRegex = map resolveRegex directoryWatchesRegex;
        resolvedContentDirectoryWatches = map resolvePath contentDirectoryWatches;
        resolvedContentDirectoryWatchesRegex = map resolveRegex contentDirectoryWatchesRegex;
        resolvedPermsChecks = map resolvePath permsChecks;
        resolvedPermsChecksRegex = map resolveRegex permsChecksRegex;

        builtinLinkTargets = {
          "/bin/sh" = "";
          "/usr/bin/env" = "";
        }
        // lib.optionalAttrs (config.environment.etc ? "nix/nix.conf") {
          "/etc/nix/nix.conf" = "/etc/static/nix/nix.conf";
        }
        // lib.optionalAttrs (config.environment.etc ? "nx/config.json") {
          "/etc/nx/config.json" = "/etc/static/nx/config.json";
        };

        mergedLinkTargets =
          builtinLinkTargets // lib.mapAttrs' (p: t: lib.nameValuePair (resolvePath p) t) linkTargets;

        hmFiles =
          if config ? home-manager && config.home-manager.users ? ${self.user.username} then
            lib.attrValues config.home-manager.users.${self.user.username}.home.file
          else
            [ ];
        linkTargetEntry =
          path: target:
          let
            etcRel = lib.removePrefix "/etc/" path;
            homeRel = lib.removePrefix "${self.user.home}/" path;
            hmFile = lib.findFirst (f: f.target == homeRel) null hmFiles;
            final =
              if lib.hasPrefix "/etc/" path && config.environment.etc ? ${etcRel} then
                "${config.environment.etc.${etcRel}.source}"
              else if lib.hasPrefix "${self.user.home}/" path && hmFile != null then
                "${hmFile.source}"
              else
                "";
          in
          {
            inherit path target final;
          };

        linkTargetEntries = lib.mapAttrsToList linkTargetEntry mergedLinkTargets;

        linkTargetsFile = lib.concatStringsSep "\n" (
          map (e: "${e.path}|${e.target}|${e.final}") linkTargetEntries
        );

        auditdWatchDirs = lib.optionals config.nx.linux.security.auditd.enable (
          lib.naturalSort (
            lib.filter (p: p != dbDir && p != stateDir) (
              lib.unique (
                lib.attrValues (
                  config.nx.linux.security.auditd.resolvedDirContentWatches
                  // config.nx.linux.security.auditd.resolvedTreeWatches
                )
              )
            )
          )
        );

        prunedTrees = [
          "/nix"
          "/proc"
          "/sys"
          "/dev"
          "/run"
          "/tmp"
          "/var/tmp"
          "/var/cache"
          "/var/lib/systemd"
          "/var/lib/nixos"
          "/root/.cache"
          dbDir
          stateDir
          logDir
        ]
        ++ resolvedSkipPaths;

        baseExcludes = [
          "/boot/loader/random-seed"
          "/root/.bash_history"
          "/root/.zsh_history"
          "/root/.nix-defexpr"
          "/root/.config/procps"
        ];

        rootEntrySelections = [
          "/$ IDENT"
          "/[^/]+$ IDENT"
          "/home/[^/]+$ IDENT"
          "!${lib.escapeRegex self.user.home}$"
        ];

        baseContentTrees = [
          "/boot"
          "/root"
          "/bin"
          "/usr"
          "/sbin"
          "/srv"
          "/opt"
        ]
        ++ lib.optional self.isX86_64 "/lib64"
        ++ lib.optional self.isAARCH64 "/lib"
        ++ [ "${self.user.home}/${defs.binForeignDir}" ];

        baseNormalTrees = [ ];

        baseDirSkeletons = [
          "/var/lib/machines"
          "/var/lib/portables"
        ];

        baseDirSkeletonsRegex = [
          "/var/lib/machines/[^/]+"
          "/var/lib/portables/[^/]+"
        ];

        contentHashedCriticalFiles = [
          "/etc/passwd"
          "/etc/group"
          "/etc/sudoers"
          "/etc/hostname"
          "/etc/machine-id"
          "/etc/ssh/ssh_host_rsa_key"
          "/etc/ssh/ssh_host_rsa_key.pub"
          "/etc/ssh/ssh_host_ed25519_key"
          "/etc/ssh/ssh_host_ed25519_key.pub"
        ];

        permsCriticalFiles = [
          "/etc/shadow"
          "/etc/subuid"
          "/etc/subgid"
        ];

        serverPermsChecks = [
          "/etc"
          "/etc/systemd"
        ];

        auditdWatchDirSelections = map (
          p: if effectiveFullRuleset then "${lib.escapeRegex p} IDENT" else "${lib.escapeRegex p}$ DIR"
        ) auditdWatchDirs;

        linkTargetSelections = map (e: "${lib.escapeRegex e.path}$ LNK") (
          lib.filter (e: e.target != "") linkTargetEntries
        );

        literalPathKinds = [
          {
            kind = "skipPaths";
            paths = prunedTrees;
          }
          {
            kind = "excludePaths";
            paths = baseExcludes ++ resolvedExcludePaths;
          }
          {
            kind = "directoryChecks";
            paths = baseDirSkeletons ++ resolvedDirectoryChecks;
          }
          {
            kind = "fileChecks";
            paths = resolvedFileChecks;
          }
          {
            kind = "contentDirectoryWatches";
            paths = baseContentTrees ++ resolvedContentDirectoryWatches;
          }
          {
            kind = "directoryWatches";
            paths = baseNormalTrees ++ resolvedDirectoryWatches;
          }
          {
            kind = "criticalFiles";
            paths = contentHashedCriticalFiles;
          }
          {
            kind = "permsCriticalFiles";
            paths =
              permsCriticalFiles ++ resolvedPermsChecks ++ lib.optionals effectiveFullRuleset serverPermsChecks;
          }
          {
            kind = "linkTargets";
            paths = lib.attrNames mergedLinkTargets;
          }
        ];

        pathKindPairs = lib.concatMap (
          b:
          map (p: {
            path = p;
            inherit (b) kind;
          }) (lib.unique b.paths)
        ) literalPathKinds;

        pathCollisions = lib.filter (
          entry: lib.length (lib.unique (map (e: e.kind) (lib.filter (e: e.path == entry) pathKindPairs))) > 1
        ) (lib.unique (map (e: e.path) pathKindPairs));

        pathCollisionMessages = map (
          p:
          "${p} (${
            lib.concatStringsSep " + " (
              lib.unique (map (e: e.kind) (lib.filter (e: e.path == p) pathKindPairs))
            )
          })"
        ) pathCollisions;

        selectionLines = lib.unique (
          map (p: "-${lib.escapeRegex p}") prunedTrees
          ++ map (p: "-${p}") resolvedSkipPathsRegex
          ++ map (p: "!${lib.escapeRegex p}") (baseExcludes ++ resolvedExcludePaths)
          ++ map (p: "!${p}") resolvedExcludePathsRegex
          ++ rootEntrySelections
          ++ map (p: "${lib.escapeRegex p}$ DIR") (baseDirSkeletons ++ resolvedDirectoryChecks)
          ++ map (p: "${p}$ DIR") (baseDirSkeletonsRegex ++ resolvedDirectoryChecksRegex)
          ++ map (p: "${lib.escapeRegex p}$ IDENT") resolvedFileChecks
          ++ map (p: "${p}$ IDENT") resolvedFileChecksRegex
          ++ map (p: "${lib.escapeRegex p} IDENT") contentHashedCriticalFiles
          ++ map (p: "${lib.escapeRegex p} PERMS") (
            permsCriticalFiles ++ resolvedPermsChecks ++ lib.optionals effectiveFullRuleset serverPermsChecks
          )
          ++ map (p: "${p} PERMS") resolvedPermsChecksRegex
          ++ map (p: "${lib.escapeRegex p} IDENT") (baseContentTrees ++ resolvedContentDirectoryWatches)
          ++ map (p: "${p} IDENT") resolvedContentDirectoryWatchesRegex
          ++ map (p: "${lib.escapeRegex p} NORMAL") (baseNormalTrees ++ resolvedDirectoryWatches)
          ++ map (p: "${p} NORMAL") resolvedDirectoryWatchesRegex
          ++ linkTargetSelections
          ++ auditdWatchDirSelections
          ++ configLines
        );

        aideConf = ''
          database_in=file:${dbDir}/active/aide.db
          database_out=file:${dbDir}/aide.db.new
          gzip_dbout=yes

          NORMAL = p+i+n+u+g+sha256+ftype
          IDENT  = p+n+u+g+sha256+ftype
          PERMS  = p+n+u+g+ftype
          DIR    = p+n+u+g+ftype
          LNK    = p+n+u+g+l+ftype

          ${lib.concatStringsSep "\n" selectionLines}
        '';
      in
      {
        assertions = [
          {
            assertion = lib.hasPrefix "/" dbDir;
            message = "linux.security.aide: dbDir must be an absolute path!";
          }
          {
            assertion = pathCollisions == [ ];
            message = "linux.security.aide: paths claimed by multiple watch kinds: ${lib.concatStringsSep ", " pathCollisionMessages}!";
          }
        ]
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: skipPaths entries must not be empty!";
        }) skipPaths
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: skipPathsRegex entries must not be empty!";
        }) skipPathsRegex
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: excludePaths entries must not be empty!";
        }) excludePaths
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: excludePathsRegex entries must not be empty!";
        }) excludePathsRegex
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: directoryChecks entries must not be empty!";
        }) directoryChecks
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: directoryChecksRegex entries must not be empty!";
        }) directoryChecksRegex
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: fileChecks entries must not be empty!";
        }) fileChecks
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: fileChecksRegex entries must not be empty!";
        }) fileChecksRegex
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: directoryWatches entries must not be empty!";
        }) directoryWatches
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: directoryWatchesRegex entries must not be empty!";
        }) directoryWatchesRegex
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: contentDirectoryWatches entries must not be empty!";
        }) contentDirectoryWatches
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: contentDirectoryWatchesRegex entries must not be empty!";
        }) contentDirectoryWatchesRegex
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: permsChecks entries must not be empty!";
        }) permsChecks
        ++ map (p: {
          assertion = p != "";
          message = "linux.security.aide: permsChecksRegex entries must not be empty!";
        }) permsChecksRegex
        ++ lib.mapAttrsToList (p: t: {
          assertion = p != "" && !lib.hasInfix "|" p && !lib.hasInfix "|" t;
          message = "linux.security.aide: linkTargets entries must have a non-empty path and must not contain pipe characters!";
        }) linkTargets;

        environment.etc."aide/aide.conf" = {
          text = aideConf;
          mode = "0444";
        };

        environment.etc."aide/link-targets" = {
          text = linkTargetsFile + "\n";
          mode = "0444";
        };

        environment.etc."aide/fstat-filter" = {
          text = lib.concatMapStrings (p: "${p}\n") (prunedTrees ++ baseExcludes ++ resolvedExcludePaths);
          mode = "0444";
        };

        environment.etc."aide/fstat-filter-regex" = {
          text = lib.concatMapStrings (p: "${p}\n") (resolvedSkipPathsRegex ++ resolvedExcludePathsRegex);
          mode = "0444";
        };

        environment.systemPackages = [
          pkgs.aide
          (mkInitScript { inherit dbDir hcEnabled; })
          (mkCheckScript { inherit config hcEnabled; })
          commitBin
        ];

        systemd.services.nx-aide-check = {
          description = "AIDE integrity check";
          environment.NX_AIDE_DEDUP = "1";
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = checkTimeoutSec;
            ExecStart = checkCoreScript config;
          }
          // lib.optionalAttrs (!hcEnabled) {
            SuccessExitStatus = [
              1
              2
              3
              4
              5
              6
              7
            ];
          };
        };

        systemd.timers.nx-aide-check = {
          description = "AIDE integrity check timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = effectiveSchedule;
            RandomizedDelaySec = randomDelaySec;
            Persistent = true;
          }
          // lib.optionalAttrs isHeadless {
            OnActiveSec = 120;
          };
        };

        systemd.services.nx-aide-check-boot = lib.mkIf (!isHeadless) {
          description = "AIDE integrity check after boot";
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = checkTimeoutSec;
            ExecStart = checkCoreScript config;
            SuccessExitStatus = [
              1
              2
              3
              4
              5
              6
              7
            ];
          };
        };

        systemd.timers.nx-aide-check-boot = lib.mkIf (!isHeadless) {
          description = "AIDE integrity check timer after boot";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnActiveSec = 120;
          };
        };

        systemd.services.nx-aide-post-boot-commit = lib.mkIf (!testingMode) {
          description = "AIDE database commit after a pending reboot";
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = checkTimeoutSec;
            ExecStart = mkPostBootCommitScript commitBin;
          };
        };

        systemd.timers.nx-aide-post-boot-commit = lib.mkIf (!testingMode) {
          description = "AIDE database commit timer after a pending reboot";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnActiveSec = 90;
          };
        };

        systemd.tmpfiles.settings."nx-aide" = {
          "${lockDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${dbDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${dbDir}/active".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${stateDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${logDir}".d = {
            mode = "0750";
            user = "root";
            group = userGroup;
            age = "${toString logRetentionDays}d";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${dbDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${self.persist}${stateDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${self.persist}${logDir}".d = {
            mode = "0750";
            user = "root";
            group = userGroup;
          };
        };

        environment.persistence."${self.persist}" = {
          directories = [
            dbDir
            stateDir
            logDir
          ];
        };
      };
  };
}
