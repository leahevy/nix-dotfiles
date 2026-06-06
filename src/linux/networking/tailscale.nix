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
  name = "tailscale";

  group = "networking";
  input = "linux";

  settings = {
    openFirewall = true;
    subnetRoutes = [ ];
    withTaildrop = false;
    exitNode = false;
    acceptRoutes = false;
    enableDashboardIntegration = false;
    nodeId = null;
    apiKeyRotatedAt = null;
    apiKeyLifetimeDays = 90;
  };

  module = {
    system =
      config:
      let
        rotationDate =
          if self.settings.apiKeyRotatedAt == null then
            null
          else
            "${toString self.settings.apiKeyRotatedAt.year}-${
              lib.fixedWidthString 2 "0" (toString self.settings.apiKeyRotatedAt.month)
            }-${lib.fixedWidthString 2 "0" (toString self.settings.apiKeyRotatedAt.day)}";
        normalizedRoutes = map (
          r:
          if lib.hasInfix "/" r then
            r
          else if lib.hasInfix ":" r then
            r + "/128"
          else
            r + "/32"
        ) self.settings.subnetRoutes;
        isServer = self.settings.exitNode || self.settings.subnetRoutes != [ ];
        isClient = self.settings.acceptRoutes;

        useRoutingFeatures =
          if isServer && isClient then
            "both"
          else if isServer then
            "server"
          else if isClient then
            "client"
          else
            "none";

        extraUpFlags = [
          "--advertise-tags=tag:${self.host.hostname}"
        ]
        ++ lib.optionals self.settings.acceptRoutes [ "--accept-routes" ]
        ++ lib.optionals self.settings.exitNode [ "--advertise-exit-node" ]
        ++ lib.optionals (normalizedRoutes != [ ]) [
          "--advertise-routes=${lib.concatStringsSep "," normalizedRoutes}"
        ];
      in
      {
        assertions = [
          {
            assertion = !(config.sops.secrets ? tailscale-api-key) || self.settings.apiKeyRotatedAt != null;
            message = "linux.networking.tailscale: apiKeyRotatedAt must be set when tailscale-api-key is configured!";
          }
          {
            assertion =
              self.settings.apiKeyRotatedAt == null
              || (
                builtins.isAttrs self.settings.apiKeyRotatedAt
                && self.settings.apiKeyRotatedAt ? year
                && self.settings.apiKeyRotatedAt ? month
                && self.settings.apiKeyRotatedAt ? day
                && builtins.isInt self.settings.apiKeyRotatedAt.year
                && builtins.isInt self.settings.apiKeyRotatedAt.month
                && builtins.isInt self.settings.apiKeyRotatedAt.day
                && self.settings.apiKeyRotatedAt.month >= 1
                && self.settings.apiKeyRotatedAt.month <= 12
                && self.settings.apiKeyRotatedAt.day >= 1
                && self.settings.apiKeyRotatedAt.day <= 31
              );
            message = "linux.networking.tailscale: apiKeyRotatedAt must be null or an attrset with integer year, month, and day fields!";
          }
          {
            assertion = builtins.isInt self.settings.apiKeyLifetimeDays && self.settings.apiKeyLifetimeDays > 0;
            message = "linux.networking.tailscale: apiKeyLifetimeDays must be a positive integer!";
          }
        ];

        sops.secrets.tailscale-auth-key = {
          format = "binary";
          sopsFile = self.profile.secretsPath "tailscale-auth-key";
          mode = "0400";
          owner = "root";
          group = "root";
        };

        services.tailscale = {
          enable = true;
          authKeyFile = config.sops.secrets.tailscale-auth-key.path;
          useRoutingFeatures = useRoutingFeatures;
          extraUpFlags = extraUpFlags;
          disableTaildrop = !self.settings.withTaildrop;
          openFirewall = self.settings.openFirewall;
        };

        environment.persistence."${self.persist}" = {
          directories = [
            "/var/lib/tailscale"
          ];
        };

        systemd.services.tailscaled-autoconnect = {
          wantedBy = lib.mkForce [ ];
          after = [ "multi-user.target" ];
          requires = lib.mkForce [ "tailscaled.service" ];
        };

        systemd.timers.tailscaled-autoconnect = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "30s";
            OnUnitInactiveSec = "300s";
          };
        };
      };

    ifEnabled.linux.server.dashboard = {
      enabled = config: {
        assertions = [
          {
            assertion = !self.settings.enableDashboardIntegration || self.settings.nodeId != null;
            message = "linux.networking.tailscale: nodeId must be set when enableDashboardIntegration is true!";
          }
        ];

        nx.linux.server.dashboard.bookmarks = lib.mkIf (!self.settings.enableDashboardIntegration) [
          {
            name = "Tailscale";
            icon = "tailscale";
            href = "https://login.tailscale.com/admin/machines";
            group = "maintenance";
          }
        ];

        nx.linux.server.dashboard.services = lib.mkIf self.settings.enableDashboardIntegration [
          {
            name = "Tailscale";
            group = "health";
            href = "https://login.tailscale.com/admin/machines";
            description = "Current node status in Tailscale";
            icon = "tailscale";
            enableSiteMonitor = false;
            widgets = [
              {
                type = "tailscale";
                deviceid = self.settings.nodeId;
                key = "{{HOMEPAGE_VAR_TAILSCALE_API_KEY}}";
              }
            ];
          }
        ];

        nx.linux.server.dashboard.homepageSecretEnvFiles =
          lib.mkIf self.settings.enableDashboardIntegration
            {
              HOMEPAGE_VAR_TAILSCALE_API_KEY = config.sops.secrets.tailscale-api-key.path;
            };
      };

      system =
        config:
        lib.mkIf self.settings.enableDashboardIntegration {
          sops.secrets.tailscale-api-key = {
            format = "binary";
            sopsFile = self.profile.secretsPath "tailscale-api-key";
            mode = "0400";
            owner = "root";
            group = "root";
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "tailscaled.service" ];
      };
    };

    ifEnabled.linux.notifications.pushover = {
      system =
        config:
        lib.mkIf (self.settings.apiKeyRotatedAt != null) {
          systemd.services.tailscale-api-key-expiry-notify = {
            description = "Tailscale API key expiry notification";
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "oneshot";
              User = "root";
              ExecStart = pkgs.writeShellScript "tailscale-api-key-expiry-notify" ''
                set -euo pipefail

                ROTATED_AT=${lib.escapeShellArg rotationDate}
                LIFETIME_DAYS=${toString self.settings.apiKeyLifetimeDays}
                MARKER_FILE=/var/lib/tailscale/.nx-api-key-last-notified
                ROTATED_EPOCH=$(${pkgs.coreutils}/bin/date -d "$ROTATED_AT" +%s 2>/dev/null || true)

                if [[ -z "$ROTATED_EPOCH" ]]; then
                  echo "Invalid tailscale apiKeyRotatedAt date: $ROTATED_AT" >&2
                  exit 1
                fi

                EXPIRY_EPOCH=$((ROTATED_EPOCH + LIFETIME_DAYS * 86400))
                NOW_EPOCH=$(${pkgs.coreutils}/bin/date +%s)
                DAYS_LEFT=$(((EXPIRY_EPOCH - NOW_EPOCH) / 86400))
                EXPIRY_DATE=$(${pkgs.coreutils}/bin/date -d "@$EXPIRY_EPOCH" +%Y-%m-%d)

                if [[ "$DAYS_LEFT" -gt 10 ]]; then
                  exit 0
                fi

                if [[ -f "$MARKER_FILE" ]] && [[ "$(${pkgs.coreutils}/bin/cat "$MARKER_FILE" 2>/dev/null || true)" == "$EXPIRY_DATE" ]]; then
                  exit 0
                fi

                if [[ "$DAYS_LEFT" -lt 0 ]]; then
                  DAYS_OVERDUE=$((0 - DAYS_LEFT))
                  ${config.nx.linux.notifications.pushover.send {
                    title = "Tailscale";
                    message = "Tailscale API key expired $DAYS_OVERDUE days ago, rotate it!";
                    shellVars = true;
                    type = "warn";
                  }}
                else
                  ${config.nx.linux.notifications.pushover.send {
                    title = "Tailscale";
                    message = "Tailscale API key expires in $DAYS_LEFT days, rotate it soon!";
                    shellVars = true;
                    type = "warn";
                  }}
                fi

                printf '%s\n' "$EXPIRY_DATE" > "$MARKER_FILE"
              '';
            };
          };

          systemd.timers.tailscale-api-key-expiry-notify = {
            description = "Daily Tailscale API key expiry notification check";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "*-*-* 10:00:00";
              Persistent = true;
              RandomizedDelaySec = 900;
            };
          };
        };
    };
  };
}
