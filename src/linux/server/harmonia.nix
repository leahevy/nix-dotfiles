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
  name = "harmonia";
  description = "Self-hosted Nix binary cache";

  group = "server";
  input = "linux";

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "cache";
      description = "Subdomain under baseDomain for the harmonia binary cache vhost.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port harmonia listens on (localhost only, nginx fronts it).";
    };

    restrictToClientNetwork = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict the nginx vhost to permitted client IPs via the nx_is_allowed geo variable.";
    };
  };

  module = {
    linux.system =
      {
        config,
        subdomain,
        port,
        restrictToClientNetwork,
        ...
      }:
      let
        exposedService = self.host.remote.exposedServices.harmonia or null;
      in
      {
        assertions = [
          {
            assertion = exposedService == null || exposedService.subdomain == subdomain;
            message = "linux.server.harmonia: subdomain '${subdomain}' does not match exposedServices.harmonia.subdomain '${
              if exposedService != null then exposedService.subdomain else ""
            }'!";
          }
        ];

        sops.secrets."harmonia-sign-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "harmonia-sign-key";
          owner = "root";
          mode = "0400";
        };

        services.harmonia.cache = {
          enable = true;
          signKeyPaths = [ config.sops.secrets."harmonia-sign-key".path ];
          settings.bind = "127.0.0.1:${toString port}";
          settings.priority = 30;
        };
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          subdomain,
          port,
          restrictToClientNetwork,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.harmonia or null;
        in
        lib.mkIf (domain != null && exposedService != null) {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              recommendedProxySettings = false;
              extraConfig = ''
                ${lib.optionalString restrictToClientNetwork "if ($nx_is_allowed = 0) { return 403; }"}
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_redirect off;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection $connection_upgrade;
              '';
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "harmonia.service" ];
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.harmonia or null;
          subdomain = config.nx.linux.server.harmonia.subdomain;
        in
        lib.mkIf (domain != null && exposedService != null) {
          nx.linux.server.dashboard.services = [
            {
              name = "Nix Cache";
              href = "#admin";
              target = "_self";
              siteMonitor = "https://${subdomain}.${domain}/nix-cache-info";
              description = "Harmonia binary cache";
              icon = "nixos";
              group = "admin";
            }
          ];
        };
    };
  };
}
