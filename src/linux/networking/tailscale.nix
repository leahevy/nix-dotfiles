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
  };

  module = {
    system =
      config:
      let
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
  };
}
