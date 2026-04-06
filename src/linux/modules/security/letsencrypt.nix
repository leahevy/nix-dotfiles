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
  name = "letsencrypt";

  group = "security";
  input = "linux";

  settings = {
    dnsCerts = { };
    extraConfigDefaults = { };
    pushoverNotifications = true;
    warningDays = 24;
    monitoringSchedule = "*-*-* 23:30:00";
  };

  on = {
    system =
      config:
      let
        pushover = config.nx.linux.notifications.pushover;
        logScript =
          level: message:
          let
            userNotifyEnabled = (self.isModuleEnabled "notifications.user-notify");
            pushoverEnabled = self.settings.pushoverNotifications;

            userNotifyTitle =
              if userNotifyEnabled then
                if lib.hasPrefix "RENEWED:" message then
                  "Let's Encrypt (renewed)"
                else if lib.hasPrefix "WARNING:" message then
                  "Let's Encrypt (warning)"
                else if lib.hasPrefix "ERROR:" message then
                  "Let's Encrypt (error)"
                else
                  "Let's Encrypt"
              else
                "";

            userNotifyMessage =
              if userNotifyEnabled then
                if lib.hasPrefix "RENEWED:" message then
                  lib.removePrefix "RENEWED: " message
                else if lib.hasPrefix "WARNING:" message then
                  lib.removePrefix "WARNING: " message
                else if lib.hasPrefix "ERROR:" message then
                  lib.removePrefix "ERROR: " message
                else
                  message
              else
                "";

            userNotifyIcon =
              if userNotifyEnabled then
                if lib.hasPrefix "RENEWED:" message then
                  "application-certificate"
                else if lib.hasPrefix "WARNING:" message then
                  "dialog-warning"
                else if lib.hasPrefix "ERROR:" message then
                  "dialog-error"
                else
                  "application-certificate"
              else
                "";

            pushoverType =
              if lib.hasPrefix "RENEWED:" message then
                "success"
              else if lib.hasPrefix "WARNING:" message then
                "warn"
              else if lib.hasPrefix "ERROR:" message then
                "failed"
              else
                null;

            shouldSendPushover = pushoverEnabled && pushoverType != null;

            pushoverMessage =
              if lib.hasPrefix "RENEWED:" message then
                lib.removePrefix "RENEWED: " message
              else if lib.hasPrefix "WARNING:" message then
                lib.removePrefix "WARNING: " message
              else if lib.hasPrefix "ERROR:" message then
                lib.removePrefix "ERROR: " message
              else
                message;
          in
          ''
            ${lib.optionalString userNotifyEnabled (
              self.notifyUser {
                inherit pkgs;
                title = userNotifyTitle;
                body = userNotifyMessage;
                icon = userNotifyIcon;
                urgency = helpers.loggerLevelToNotifyLevel level;
                validation = { inherit config; };
              }
            )}
            ${lib.optionalString shouldSendPushover (
              pushover.send {
                title = "Let's Encrypt";
                message = pushoverMessage;
                type = pushoverType;
              }
            )}
            echo "${message}" ${if level == "err" then ">&2" else ""}
          '';
      in
      {
        environment.persistence."${self.persist}" = {
          directories = [
            "/var/lib/acme"
          ];
        };

        sops.secrets."letsencrypt-dns" = lib.mkIf (self.settings.dnsCerts != { }) {
          format = "binary";
          sopsFile = self.config.secretsPath "letsencrypt-dns";
          mode = "0400";
          owner = "acme";
          group = "acme";
        };

        security.acme = lib.mkIf (self.settings.dnsCerts != { }) {
          acceptTerms = true;

          defaults = {
            email = self.user.email;
            environmentFile = config.sops.secrets."letsencrypt-dns".path;
          };

          certs = lib.mapAttrs (
            domain: certConfig:
            self.settings.extraConfigDefaults
            // {
              dnsProvider = certConfig.provider;
              group = certConfig.group or "acme";
              postRun = ''
                ${logScript "info" "RENEWED: Certificate ${domain} successfully renewed!"}
              '';
            }
            // (certConfig.extraConfig or { })
          ) self.settings.dnsCerts;
        };

        systemd.services = lib.mkMerge [
          (lib.mkIf (self.settings.dnsCerts != { }) (
            lib.mapAttrs' (
              domain: certConfig:
              lib.nameValuePair "acme-monitoring-${domain}" {
                description = "Monitor ACME certificate expiration for ${domain}";
                serviceConfig = {
                  Type = "oneshot";
                  User = "root";
                };
                script = ''
                  CERT_PATH="/var/lib/acme/${domain}/cert.pem"

                  if [ ! -f "$CERT_PATH" ]; then
                    ${logScript "err" "ERROR: Certificate file not found for ${domain} at $CERT_PATH!"}
                    exit 1
                  fi

                  EXPIRY=$(${pkgs.openssl}/bin/openssl x509 -enddate -noout -in "$CERT_PATH" | cut -d= -f2)
                  if [ $? -ne 0 ]; then
                    ${logScript "err" "ERROR: Failed to read certificate expiration for ${domain}!"}
                    exit 1
                  fi

                  EXPIRY_EPOCH=$(${pkgs.coreutils}/bin/date -d "$EXPIRY" +%s)
                  CURRENT_EPOCH=$(${pkgs.coreutils}/bin/date +%s)
                  DAYS_LEFT=$(((EXPIRY_EPOCH - CURRENT_EPOCH) / 86400))

                  if [ $DAYS_LEFT -lt ${toString self.settings.warningDays} ]; then
                    ${logScript "warning" "WARNING: Certificate ${domain} expires in $DAYS_LEFT days!"}
                  fi
                '';
              }
            ) self.settings.dnsCerts
          ))
          (lib.mkIf (self.settings.dnsCerts != { }) {
            acme-monitoring = {
              description = "ACME certificate monitoring";
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = false;
              };
              wants = lib.mapAttrsToList (domain: _: "acme-monitoring-${domain}.service") self.settings.dnsCerts;
              after = lib.mapAttrsToList (domain: _: "acme-monitoring-${domain}.service") self.settings.dnsCerts;
              script = ''
                echo "Certificate monitoring completed for all domains"
              '';
            };
          })
        ];

        systemd.timers.acme-monitoring = lib.mkIf (self.settings.dnsCerts != { }) {
          description = "Timer for ACME certificate monitoring";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = self.settings.monitoringSchedule;
            Persistent = true;
          };
        };
      };
  };
}
