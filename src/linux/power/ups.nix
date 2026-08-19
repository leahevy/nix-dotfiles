args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "ups";

  group = "power";
  input = "linux";

  description = "UPS monitoring via NUT with pushover notifications";

  disableOnVirtual = true;

  options = {
    upsName = lib.mkOption {
      type = lib.types.str;
      default = "ups";
      description = "Internal NUT name for the UPS";
    };
    upsDriver = lib.mkOption {
      type = lib.types.str;
      default = "usbhid-ups";
      description = "NUT driver for the UPS";
    };
    upsDescription = lib.mkOption {
      type = lib.types.str;
      default = "UPS";
      description = "Generic UPS description without device specifics";
    };
    deviceMatch = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        vendorid = "ffff";
        productid = "ffff";
      };
      description = "Device match directives injected by the host profile to bind a specific UPS, required when the module is enabled";
    };
    offdelay = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Seconds the UPS waits before cutting output power after being told to shut down, only takes effect on the killpower path";
    };
    ondelay = lib.mkOption {
      type = lib.types.int;
      default = 70;
      description = "Seconds before the UPS restores output power after mains returns, must be greater than offdelay for a clean power cycle";
    };
    notifyThrottle = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = {
        LOWBATT = 3600;
        COMMBAD = 21600;
      };
      description = "Minimum seconds between pushover notifications per UPS event type, missing or zero means no throttle, REPLBATT and NOCOMM are handled natively by RBWARNTIME and NOCOMMWARNTIME instead";
    };
    rbWarnTime = lib.mkOption {
      type = lib.types.int;
      default = 86400;
      description = "Seconds between REPLBATT re-warning notifications, handled natively by upsmon RBWARNTIME";
    };
    noCommWarnTime = lib.mkOption {
      type = lib.types.int;
      default = 21600;
      description = "Seconds between NOCOMM re-warning notifications, handled natively by upsmon NOCOMMWARNTIME";
    };
    notifyMessages = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        ONLINE = "Back on mains power";
        ONBATT = "On battery power";
        LOWBATT = "Battery is low";
        FSD = "Forced shutdown in progress";
        COMMOK = "UPS communications restored";
        COMMBAD = "UPS communications lost";
        SHUTDOWN = "Shutdown in progress";
        REPLBATT = "Battery needs replacement";
        NOCOMM = "UPS not available";
        NOPARENT = "upsmon parent process died";
      };
      description = "Notification message text per UPS event type, overrides NUT defaults";
    };

    startupCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "NUT instant commands issued once after the driver starts, each run via upscmd and allowed to fail";
    };
    disableBeeper = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable the UPS beeper on startup by issuing the beeper.disable instant command";
    };
    enableAutomaticShutdown = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable delayed graceful shutdown after a prolonged on battery period, notification only when this is off";
    };
    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Exercise the on battery timer, notifications and dispatcher but log the teardown and poweroff instead of running them, only meaningful when enableAutomaticShutdown is set";
    };
    onBatteryTimeout = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Seconds on battery before a graceful shutdown is triggered, only used when enableAutomaticShutdown is set";
    };
    shutdownCommandTimeout = lib.mkOption {
      type = lib.types.int;
      default = 180;
      description = "Default seconds allowed for each graceful teardown command before it is considered failed";
    };
    killCommandTimeout = lib.mkOption {
      type = lib.types.int;
      default = 60;
      description = "Seconds allowed for a teardown kill escalation command";
    };
    onBatteryShutdownCommands = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Label used in shutdown teardown logs";
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "Graceful teardown command run as root before poweroff";
            };
            killCommand = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Optional escalation command run when the graceful command fails or times out";
            };
            timeout = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Seconds allowed for the graceful command, null uses shutdownCommandTimeout";
            };
          };
        }
      );
      default = [ ];
      description = "Root teardown commands run in order before the automatic poweroff, each isolated with its own timeout and optional kill escalation";
    };
  };

  module = {
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          service = "upsmon.service";
          tag = "upsmon";
          string = "Poll UPS \\[ups@localhost\\] failed - Driver not connected";
        }
        {
          service = "upsmon.service";
          tag = "upsmon";
          string = "UPS \\[ups@localhost\\]: connect failed: Connection failure: Connection refused";
        }
        {
          service = "upsd.service";
          tag = "upsd";
          string = "WARNING: /etc/nut/upsd\\.conf is world readable \\(hope you don't have passwords there\\)";
        }
        {
          service = "upsd.service";
          tag = "upsd";
          string = "mainloop: Interrupted system call";
        }
        {
          service = "upsd.service";
          tag = "upsd";
          string = "Can't connect to UPS \\[ups\\] \\(/var/lib/nut/usbhid-ups-ups\\): No such file or directory";
        }
      ];
    };

    ifEnabled.linux.notifications.pushover.enabled = config: {
      nx.linux.notifications.pushover.additionalUsers = [ config.power.ups.upsmon.user ];
    };

    ifEnabled.linux.server.healthchecks.enabled = config: {
      nx.linux.server.healthchecks.requireServicesUp = [
        "upsd.service"
        "upsmon.service"
      ];
    };

    linux.system =
      {
        config,
        upsName,
        upsDriver,
        upsDescription,
        deviceMatch,
        offdelay,
        ondelay,
        notifyMessages,
        notifyThrottle,
        rbWarnTime,
        noCommWarnTime,
        startupCommands,
        disableBeeper,
        enableAutomaticShutdown,
        dryRun,
        onBatteryTimeout,
        shutdownCommandTimeout,
        killCommandTimeout,
        onBatteryShutdownCommands,
        ...
      }:
      let
        monitorUser = "upsmon";
        varDir = "/var/lib/nx-ups";
        stateDir = "/run/nx-ups";
        passwordFile = "${varDir}/monitor-password";
        upsmonUser = config.power.ups.upsmon.user;
        upsmonGroup = config.power.ups.upsmon.group;
        realShutdown = enableAutomaticShutdown && !dryRun;

        pushover = config.nx.linux.notifications.pushover;
        pushoverEnabled = self.isModuleEnabled "notifications.pushover" && pushover.script != null;

        passwordGenerator = pkgs.writeShellScript "ups-generate-monitor-password" ''
          set -eu
          umask 077
          if [ ! -s "${passwordFile}" ]; then
            ${pkgs.openssl}/bin/openssl rand -hex 32 > "${passwordFile}"
            ${pkgs.coreutils}/bin/chmod 600 "${passwordFile}"
          fi
        '';

        startupCommandList = startupCommands ++ lib.optional disableBeeper "beeper.disable";
        grantedInstcmds = lib.unique (map (c: lib.head (lib.splitString " " c)) startupCommandList);
        upscmdAuth = pkgs.writeScript "ups-upscmd-auth" ''
          #!${pkgs.expect}/bin/expect -f
          log_user 0
          set timeout 15
          set pwfile [lindex $argv 0]
          set target [lindex $argv 1]
          set user [lindex $argv 2]
          set cmd [lrange $argv 3 end]
          set fh [open $pwfile r]
          set pw [string trim [read $fh]]
          close $fh
          spawn ${config.power.ups.package}/bin/upscmd -u $user $target {*}$cmd
          expect {
            -re "assword" { send -- "$pw\r" }
            timeout { exit 1 }
            eof { exit 1 }
          }
          expect eof
          catch wait result
          exit [lindex $result 3]
        '';
        startupCommandsScript = pkgs.writeShellScript "ups-startup-commands" ''
          set -eu
          ${lib.concatMapStringsSep "\n" (
            cmd:
            "${upscmdAuth} ${lib.escapeShellArg passwordFile} ${upsName}@localhost ${monitorUser} ${cmd} || true"
          ) startupCommandList}
        '';

        shutdownSuppressed = pkgs.writeShellScript "ups-shutdown-suppressed" ''
          ${pkgs.util-linux}/bin/logger -t nx-ups "UPS reached forced shutdown but automatic poweroff is disabled!"
        '';

        throttleCases = lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            event: seconds: "            ${event}) throttle=${toString seconds} ;;"
          ) notifyThrottle
        );

        notifyScript = pkgs.writeShellScript "ups-notify" ''
          set -eu
          MESSAGE="''${1:-UPS event}"
          TYPE="''${NOTIFYTYPE:-UNKNOWN}"

          throttle=0
          case "$TYPE" in
          ${throttleCases}
          esac

          if [ "$throttle" -gt 0 ]; then
            stamp="${stateDir}/$TYPE"
            now=$(${pkgs.coreutils}/bin/date +%s)
            if [ -f "$stamp" ]; then
              last=$(${pkgs.coreutils}/bin/cat "$stamp" 2>/dev/null || printf '0')
              if [ $((now - last)) -lt "$throttle" ]; then
                exit 0
              fi
            fi
            printf '%s' "$now" > "$stamp"
          fi

          case "$TYPE" in
            ONBATT|LOWBATT|FSD|SHUTDOWN|COMMBAD|NOCOMM|REPLBATT)
              ${
                if pushoverEnabled then
                  pushover.send {
                    title = "UPS";
                    message = "$MESSAGE";
                    type = "warn";
                    shellVars = true;
                  }
                else
                  ":"
              }
              ;;
            *)
              ${
                if pushoverEnabled then
                  pushover.send {
                    title = "UPS";
                    message = "$MESSAGE";
                    type = "info";
                    shellVars = true;
                  }
                else
                  ":"
              }
              ;;
          esac
        '';

        loggerBin = "${pkgs.util-linux}/bin/logger";
        timeoutBin = "${pkgs.coreutils}/bin/timeout";
        touchBin = "${pkgs.coreutils}/bin/touch";
        teardownShell = pkgs.runtimeShell;
        fsdRequest = "${stateDir}/fsd-request";

        shutdownCommandsBlock = lib.concatMapStringsSep "\n" (
          c:
          let
            graceTimeout = if c.timeout != null then c.timeout else shutdownCommandTimeout;
            killBlock = lib.optionalString (c.killCommand != null) ''
              ${loggerBin} -t nx-ups "teardown '${c.name}': escalating to kill command"
              if ${timeoutBin} ${toString killCommandTimeout} ${teardownShell} -c ${lib.escapeShellArg c.killCommand}; then
                ${loggerBin} -t nx-ups "teardown '${c.name}': kill command completed"
              else
                ${loggerBin} -t nx-ups "teardown '${c.name}': kill command failed with status $?"
              fi'';
          in
          ''
            ${loggerBin} -t nx-ups "teardown '${c.name}': starting (timeout ${toString graceTimeout}s)"
            if ${timeoutBin} ${toString graceTimeout} ${teardownShell} -c ${lib.escapeShellArg c.command}; then
              ${loggerBin} -t nx-ups "teardown '${c.name}': completed"
            else
              ${loggerBin} -t nx-ups "teardown '${c.name}': failed or timed out with status $?"
            ${killBlock}
            fi''
        ) onBatteryShutdownCommands;

        teardownScript = pkgs.writeShellScript "ups-graceful-shutdown" ''
          set -u
          ${loggerBin} -t nx-ups "UPS forced shutdown reached, running graceful teardown"
          ${shutdownCommandsBlock}
          ${loggerBin} -t nx-ups "UPS teardown finished, powering off"
          ${pkgs.systemd}/bin/systemctl poweroff -i
        '';

        dryShutdownBlock = lib.concatMapStringsSep "\n" (
          c:
          let
            graceTimeout = if c.timeout != null then c.timeout else shutdownCommandTimeout;
            killLine =
              lib.optionalString (c.killCommand != null)
                "\n${loggerBin} -t nx-ups ${lib.escapeShellArg "DRY RUN teardown '${c.name}': would escalate to kill: ${c.killCommand}"}";
          in
          "${loggerBin} -t nx-ups ${lib.escapeShellArg "DRY RUN teardown '${c.name}': would run (timeout ${toString graceTimeout}s): ${c.command}"}${killLine}"
        ) onBatteryShutdownCommands;

        dryTeardownScript = pkgs.writeShellScript "ups-graceful-shutdown-dryrun" ''
          ${loggerBin} -t nx-ups "DRY RUN: UPS forced shutdown reached, teardown and poweroff suppressed"
          ${dryShutdownBlock}
          ${loggerBin} -t nx-ups "DRY RUN: would power off with systemctl poweroff -i"
        '';

        dispatcherScript = pkgs.writeShellScript "ups-upssched-cmd" ''
          set -u
          case "$1" in
            onbatt-timeout)
              ${
                if pushoverEnabled then
                  pushover.send {
                    title = "UPS";
                    message =
                      if dryRun then
                        "DRY RUN: on battery for ${toString onBatteryTimeout}s, graceful shutdown suppressed"
                      else
                        "On battery for ${toString onBatteryTimeout}s, starting graceful shutdown";
                    type = "warn";
                  }
                else
                  ":"
              }
              ${if dryRun then "${dryTeardownScript}" else "${touchBin} ${fsdRequest}"}
              ;;
          esac
        '';

        upsschedConf = pkgs.writeText "upssched.conf" ''
          CMDSCRIPT ${dispatcherScript}
          PIPEFN ${stateDir}/upssched.pipe
          LOCKFN ${stateDir}/upssched.lock
          AT ONBATT * START-TIMER onbatt-timeout ${toString onBatteryTimeout}
          AT ONLINE * CANCEL-TIMER onbatt-timeout
        '';

        upsschedWrapper = pkgs.writeShellScript "ups-notify-sched" ''
          ${notifyScript} "$@" || true
          ${config.power.ups.package}/bin/upssched || true
        '';
      in
      {
        assertions = [
          {
            assertion = deviceMatch != { };
            message = "linux.power.ups: deviceMatch is empty, inject vendorid/productid/serial from the host profile!";
          }
          {
            assertion = !enableAutomaticShutdown || onBatteryTimeout > 0;
            message = "linux.power.ups: onBatteryTimeout must be greater than zero when enableAutomaticShutdown is set!";
          }
          {
            assertion = !enableAutomaticShutdown || ondelay > offdelay;
            message = "linux.power.ups: ondelay must be greater than offdelay for the UPS to power cycle cleanly!";
          }
          {
            assertion = !(notifyThrottle ? REPLBATT || notifyThrottle ? NOCOMM);
            message = "linux.power.ups: REPLBATT and NOCOMM are throttled by rbWarnTime and noCommWarnTime, remove them from notifyThrottle!";
          }
        ];

        environment.persistence."${self.persist}".directories = [ varDir ];

        systemd.tmpfiles.settings."10-nx-ups" = {
          "${varDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
          "${stateDir}".d = {
            mode = "0700";
            user = upsmonUser;
            group = upsmonGroup;
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${varDir}".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
        };

        systemd.services.ups-monitor-password = {
          description = "Generate NUT upsd monitor password";
          wantedBy = [ "multi-user.target" ];
          before = [
            "upsd.service"
            "upsmon.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${passwordGenerator}";
          };
        };

        systemd.services.ups-startup-commands = lib.mkIf (startupCommandList != [ ]) {
          description = "Run declarative NUT instant commands after the driver starts";
          wantedBy = [ "multi-user.target" ];
          after = [
            "upsd.service"
            "upsdrv.service"
            "ups-monitor-password.service"
          ];
          requires = [
            "upsd.service"
            "upsdrv.service"
            "ups-monitor-password.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${startupCommandsScript}";
          };
        };

        systemd.services.upsd = {
          after = [ "ups-monitor-password.service" ];
          requires = [ "ups-monitor-password.service" ];
        };
        systemd.services.upsmon = {
          after = [ "ups-monitor-password.service" ];
          requires = [ "ups-monitor-password.service" ];
        };

        systemd.services.ups-onbatt-shutdown = lib.mkIf realShutdown {
          description = "Force NUT forced shutdown after a prolonged on battery timeout";
          environment = {
            NUT_CONFPATH = "/etc/nut";
            NUT_STATEPATH = "/var/lib/nut";
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${fsdRequest}";
            ExecStart = "${config.power.ups.package}/sbin/upsmon -c fsd";
          };
        };

        systemd.paths.ups-onbatt-shutdown = lib.mkIf realShutdown {
          description = "Watch for the NUT on battery shutdown request flag";
          wantedBy = [ "multi-user.target" ];
          pathConfig.PathExists = fsdRequest;
        };

        power.ups = {
          enable = true;
          mode = "standalone";
          schedulerRules = lib.mkIf enableAutomaticShutdown "${upsschedConf}";

          ups.${upsName} = {
            driver = upsDriver;
            port = "auto";
            description = upsDescription;
            directives =
              lib.mapAttrsToList (k: v: "${k} = ${v}") deviceMatch
              ++ lib.optionals realShutdown [
                "offdelay = ${toString offdelay}"
                "ondelay = ${toString ondelay}"
              ];
          };

          upsd.listen = [ { address = "127.0.0.1"; } ];

          users.${monitorUser} = {
            inherit passwordFile;
            upsmon = "primary";
            instcmds = grantedInstcmds;
          };

          upsmon.monitor.${upsName} = {
            system = "${upsName}@localhost";
            user = monitorUser;
            type = "primary";
          };

          upsmon.settings = {
            NOTIFYMSG = lib.mapAttrsToList (event: msg: [
              event
              msg
            ]) notifyMessages;
            NOTIFYCMD = if enableAutomaticShutdown then "${upsschedWrapper}" else "${notifyScript}";
            SHUTDOWNCMD =
              if enableAutomaticShutdown then
                (if dryRun then "${dryTeardownScript}" else "${teardownScript}")
              else
                "${shutdownSuppressed}";
            POWERDOWNFLAG = if realShutdown then "/run/killpower" else null;
            RBWARNTIME = rbWarnTime;
            NOCOMMWARNTIME = noCommWarnTime;
            NOTIFYFLAG = [
              [
                "ONLINE"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "ONBATT"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "LOWBATT"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "FSD"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "COMMOK"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "COMMBAD"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "SHUTDOWN"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "REPLBATT"
                "SYSLOG+WALL+EXEC"
              ]
              [
                "NOCOMM"
                "SYSLOG+WALL+EXEC"
              ]
            ];
          };
        };
      };
  };
}
