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
  namespace = "system";

  settings = {
    openFirewall = true;
    subnetRoutes = [ ];
    withTaildrop = false;
    exitNode = false;
    acceptRoutes = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
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
        "--accept-routes"
        "--advertise-tags=tag:${self.host.hostname}"
      ]
      ++ lib.optionals self.settings.exitNode [
        "--advertise-exit-node"
      ]
      ++ lib.optionals (self.settings.subnetRoutes != [ ]) [
        "--advertise-routes=${lib.concatStringsSep "," self.settings.subnetRoutes}"
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
}
