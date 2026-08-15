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
  };

  module = {
    linux.system =
      {
        config,
        upsName,
        upsDriver,
        upsDescription,
        deviceMatch,
        notifyThrottle,
        rbWarnTime,
        noCommWarnTime,
        ...
      }:
      let
        monitorUser = "upsmon";
        varDir = "/var/lib/nx-ups";
        stateDir = "/run/nx-ups";
        passwordFile = "${varDir}/monitor-password";
        upsmonUser = config.power.ups.upsmon.user;
        upsmonGroup = config.power.ups.upsmon.group;

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
      in
      {
        assertions = [
          {
            assertion = deviceMatch != { };
            message = "linux.power.ups: deviceMatch is empty, inject vendorid/productid/serial from the host profile!";
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

        systemd.services.upsd = {
          after = [ "ups-monitor-password.service" ];
          requires = [ "ups-monitor-password.service" ];
        };
        systemd.services.upsmon = {
          after = [ "ups-monitor-password.service" ];
          requires = [ "ups-monitor-password.service" ];
        };

        power.ups = {
          enable = true;
          mode = "standalone";

          ups.${upsName} = {
            driver = upsDriver;
            port = "auto";
            description = upsDescription;
            directives = lib.mapAttrsToList (k: v: "${k} = ${v}") deviceMatch;
          };

          upsd.listen = [ { address = "127.0.0.1"; } ];

          users.${monitorUser} = {
            inherit passwordFile;
            upsmon = "primary";
          };

          upsmon.monitor.${upsName} = {
            system = "${upsName}@localhost";
            user = monitorUser;
            type = "primary";
          };

          upsmon.settings = {
            NOTIFYCMD = "${notifyScript}";
            SHUTDOWNCMD = "${shutdownSuppressed}";
            POWERDOWNFLAG = null;
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
