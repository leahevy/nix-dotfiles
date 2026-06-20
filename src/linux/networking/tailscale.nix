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

  submodules = {
    linux.security.api-keys = true;
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
      enabled =
        config:
        lib.mkMerge [
          (lib.mkIf self.settings.enableDashboardIntegration {
            nx.linux.security.api-keys.keys.tailscale = {
              displayName = "Tailscale";
              secretName = lib.mkDefault "tailscale-api-key";
              lifetimeDays = lib.mkDefault 90;
              healthchecksIcon = "tailscale";
            };
          })
          {
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
                group = "links-admin";
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
          }
        ];

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
        nx.linux.server.healthchecks.regularHealthChecks = {
          "R+35 - Tailscale status" = ''
            _ts_marker=/run/nx-healthcheck/tailscale-last-seen-connected
            _ts_grace=1200
            _ts_json=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null || true)
            if printf '%s' "$_ts_json" \
              | ${pkgs.jq}/bin/jq -e '.BackendState == "Running" and (.TailscaleIPs | length) > 0 and .Self.Online == true' >/dev/null 2>&1; then
              ${pkgs.coreutils}/bin/touch "$_ts_marker"
            else
              _ts_state=$(printf '%s' "$_ts_json" \
                | ${pkgs.jq}/bin/jq -r '.BackendState // "unknown"' 2>/dev/null || echo "unknown")
              if [[ "$_ts_state" == "Running" ]]; then
                _ts_last=0
                if [[ -f "$_ts_marker" ]]; then
                  _ts_last=$(${pkgs.coreutils}/bin/stat -c %Y "$_ts_marker" 2>/dev/null || echo 0)
                fi
                _ts_age=$(( $(${pkgs.coreutils}/bin/date +%s) - _ts_last ))
                if [[ $_ts_age -lt $_ts_grace ]]; then
                  if [[ $_ts_age -lt 60 ]]; then
                    _ts_ago="''${_ts_age}s ago"
                  elif [[ $_ts_age -lt 3600 ]]; then
                    _ts_ago="$((_ts_age / 60))m ago"
                  else
                    _ts_ago="$((_ts_age / 3600))h ago"
                  fi
                  printf 'not connected (state: %s, last-connected: %s)\n' "$_ts_state" "$_ts_ago" >&3
                  exit 0
                fi
              fi
              printf 'not connected (state: %s)\n' "$_ts_state" >&3
              exit 1
            fi
          '';
        };
      };
    };

  };
}
