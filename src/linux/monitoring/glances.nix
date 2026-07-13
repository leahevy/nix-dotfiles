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
  name = "glances";
  description = "Glances system monitoring web server";

  group = "monitoring";
  input = "linux";

  options = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 61208;
      description = "Local port the glances web server listens on.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "glances";
      description = "Subdomain under baseDomain where the glances web UI is served.";
    };

    apiSubdomain = lib.mkOption {
      type = lib.types.str;
      default = "glances-api";
      description = "Subdomain under baseDomain serving the basic-auth REST API endpoint for machine clients.";
    };

    internalOnly = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Restrict both vhosts to internal clients via the nx_is_internal nginx guard.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional command line arguments appended to the glances invocation.";
    };

    enableHealthCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Add glances API and auth enforcement probes to the regular health check.";
    };

    dashboardWidgetMetric = lib.mkOption {
      type = lib.types.str;
      default = "info";
      description = "Metric shown by the homepage glances widget on the dashboard card.";
    };

    uiAllowedGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "ldap-users" ];
      description = "LDAP groups allowed to access the web UI through the oauth2 proxy.";
    };
  };

  module = {
    linux.system =
      {
        config,
        port,
        subdomain,
        extraArgs,
        uiAllowedGroups,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        exposedService = self.host.remote.exposedServices.glances;
        uiExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else "glances";
      in
      {
        assertions = [
          {
            assertion = config.nx.linux.security.letsencrypt.enable;
            message = "linux.monitoring.glances requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = domain != null;
            message = "linux.monitoring.glances requires host.remote.baseDomain to be set!";
          }
          {
            assertion = exposedService == false || exposedSubdomain == subdomain;
            message = "linux.monitoring.glances: subdomain '${subdomain}' does not match exposedServices.glances subdomain '${exposedSubdomain}'!";
          }
          {
            assertion =
              !uiExposed || (config.nx.linux.server.auth.enable && config.nx.linux.server.auth.enableOAuthProxy);
            message = "linux.monitoring.glances: exposing the web UI requires linux.server.auth with enableOAuthProxy!";
          }
          {
            assertion = !uiExposed || uiAllowedGroups != [ ];
            message = "linux.monitoring.glances: exposing the web UI requires at least one group in uiAllowedGroups!";
          }
        ];

        services.glances = {
          enable = true;
          inherit port;
          extraArgs = [
            "--webserver"
            "-B"
            "127.0.0.1"
          ]
          ++ lib.optional (!uiExposed) "--disable-webui"
          ++ extraArgs;
        };

        sops.secrets."${self.host.hostname}-glances-htpasswd" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "glances-htpasswd";
          owner = config.services.nginx.user;
          mode = "0400";
        };
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          port,
          subdomain,
          apiSubdomain,
          internalOnly,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.glances;
          uiExposed = exposedService != false;
          internalGuard = lib.optionalString internalOnly ''
            if ($nx_is_internal = 0) { return 403; }
          '';
          proxyHeaders = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        in
        {
          services.nginx.virtualHosts = {
            "${apiSubdomain}.${domain}" = {
              useACMEHost = domain;
              forceSSL = true;
              locations."/api/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                basicAuthFile = config.sops.secrets."${self.host.hostname}-glances-htpasswd".path;
                recommendedProxySettings = false;
                extraConfig = internalGuard + proxyHeaders;
              };
              locations."/".return = "404";
            };
          }
          // lib.optionalAttrs uiExposed {
            "${subdomain}.${domain}" = {
              useACMEHost = domain;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                recommendedProxySettings = false;
                extraConfig = internalGuard + proxyHeaders;
              };
            };
          };
        };
    };

    ifEnabled.linux.server.auth = {
      enabled =
        config:
        let
          exposedService = self.host.remote.exposedServices.glances;
          uiExposed = exposedService != false;
        in
        lib.mkIf uiExposed {
          nx.linux.server.auth.proxyProtectedVhosts = [
            {
              vhost = config.nx.linux.monitoring.glances.subdomain;
              allowedGroups = config.nx.linux.monitoring.glances.uiAllowedGroups;
            }
          ];
        };
    };

    ifEnabled.linux.server.ldap = {
      linux.system =
        { config, uiAllowedGroups, ... }:
        let
          exposedService = self.host.remote.exposedServices.glances;
          uiExposed = exposedService != false;
        in
        {
          assertions = map (g: {
            assertion = !uiExposed || g == "ldap-users" || builtins.elem g config.nx.linux.server.ldap.groups;
            message = "linux.monitoring.glances: UI group '${g}' is not declared in linux.server.ldap.groups!";
          }) uiAllowedGroups;
        };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          gl = config.nx.linux.monitoring.glances;
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.glances;
          uiExposed = exposedService != false;
          href =
            if uiExposed then
              "https://${gl.subdomain}.${domain}"
            else
              "https://${gl.apiSubdomain}.${domain}/api/4/status";
        in
        {
          nx.linux.server.dashboard.services = [
            {
              name = "Glances";
              group = "admin";
              inherit href;
              description = "System monitoring";
              icon = "glances";
              enableSiteMonitor = true;
              widgets = [
                {
                  type = "glances";
                  url = "http://127.0.0.1:${toString gl.port}";
                  version = 4;
                  metric = gl.dashboardWidgetMetric;
                }
              ];
            }
          ];
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        let
          gl = config.nx.linux.monitoring.glances;
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.glances;
          uiExposed = exposedService != false;
        in
        {
          nx.linux.server.healthchecks.requireServicesUp = [ "glances.service" ];
          nx.linux.server.healthchecks.regularHealthChecks = lib.mkIf gl.enableHealthCheck (
            {
              "R+55 - Glances API responds" = ''
                RESPONSE=$(${pkgs.curl}/bin/curl -fsS --connect-timeout 5 --max-time 10 \
                  "http://127.0.0.1:${toString gl.port}/api/4/status" 2>&1) || {
                  printf '%s\n' "$RESPONSE" >&3
                  exit 1
                }
                printf '%s\n' "$RESPONSE" >&3
              '';
              "R+56 - Glances API auth enforced" = ''
                CODE=$(${pkgs.curl}/bin/curl -s -o /dev/null -w '%{http_code}' \
                  --connect-timeout 5 --max-time 10 \
                  "https://${gl.apiSubdomain}.${domain}/api/4/status" || true)
                printf 'api vhost status: %s\n' "$CODE" >&3
                case "$CODE" in
                  401|403) exit 0 ;;
                  *) exit 1 ;;
                esac
              '';
            }
            // lib.optionalAttrs uiExposed {
              "R+57 - Glances UI SSO enforced" = ''
                CODE=$(${pkgs.curl}/bin/curl -s -o /dev/null -w '%{http_code}' \
                  --connect-timeout 5 --max-time 10 \
                  "https://${gl.subdomain}.${domain}/" || true)
                printf 'ui vhost status: %s\n' "$CODE" >&3
                case "$CODE" in
                  302|307|401|403) exit 0 ;;
                  *) exit 1 ;;
                esac
              '';
            }
          );
        };
    };
  };
}
