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
        nx.linux.server.dashboard.bookmarks = [
          {
            name = "Tailscale Machines";
            icon = "tailscale";
            href = "https://login.tailscale.com/admin/machines";
            group = "maintenance";
          }
        ];
      };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "tailscaled.service" ];
      };
    };
  };
}
