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
  name = "searxng";
  description = "SearXNG privacy-respecting metasearch engine";

  group = "server";
  input = "linux";

  options = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 8889;
      description = "Local port the SearXNG service listens on.";
    };

    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "search";
      description = "Subdomain under baseDomain where SearXNG is served via nginx.";
    };

    extraDefaultEngines = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional engine names from SearXNG's built-in set to enable alongside Startpage.";
    };

    fontFamily = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "monospace";
      description = "CSS font-family for the SearXNG UI, or null to use the browser default.";
    };

    squareCorners = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Remove all border-radius from every element in the SearXNG UI.";
    };

    extraEngines = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = [ ];
      description = "Additional search engine configurations contributed by other modules.";
    };

    extraEnvironmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional environment file paths whose variables are substituted into engine configuration.";
    };
  };

  module = {
    linux.system =
      {
        config,
        port,
        subdomain,
        extraDefaultEngines,
        extraEngines,
        extraEnvironmentFiles,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        exposedService = self.host.remote.exposedServices.searxng;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;
        envFile = "/run/nx-searxng-env/env";
        allEnvFiles = [ envFile ] ++ extraEnvironmentFiles;
      in
      {
        assertions = [
          {
            assertion = domain != null;
            message = "linux.server.searxng requires host.remote.baseDomain to be set!";
          }
          {
            assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.searxng requires linux.security.letsencrypt to be enabled when exposed!";
          }
          {
            assertion = exposedService == false || exposedSubdomain == subdomain;
            message = "linux.server.searxng: subdomain '${subdomain}' does not match exposedServices.searxng subdomain '${exposedSubdomain}'!";
          }
        ];

        environment.persistence."${self.persist}" = {
          directories = [ "/var/lib/searx" ];
        };

        systemd.services.nx-searxng-secret = {
          description = "Prepare SearXNG secret key environment";
          before = [ "searx-init.service" ];
          wantedBy = [ "searx-init.service" ];
          partOf = [ "searx-init.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "searx";
            Group = "searx";
            StateDirectory = "searx";
            StateDirectoryMode = "0750";
            RuntimeDirectory = "nx-searxng-env";
            RuntimeDirectoryMode = "0700";
            ExecStart = toString (
              pkgs.writeShellScript "nx-searxng-secret" ''
                set -euo pipefail
                if [ ! -f /var/lib/searx/secret_key ]; then
                  ${pkgs.openssl}/bin/openssl rand -hex 32 > /var/lib/searx/secret_key
                  ${pkgs.coreutils}/bin/chmod 600 /var/lib/searx/secret_key
                fi
                umask 077
                {
                  printf 'SEARXNG_SECRET_KEY='
                  ${pkgs.coreutils}/bin/cat /var/lib/searx/secret_key
                } > /run/nx-searxng-env/env
              ''
            );
          };
        };

        systemd.services.searx-init = {
          after = [ "nx-searxng-secret.service" ];
          bindsTo = [ "nx-searxng-secret.service" ];
          restartTriggers = [ config.systemd.services.nx-searxng-secret.serviceConfig.ExecStart ];
          serviceConfig.EnvironmentFile = allEnvFiles;
        };

        systemd.services.searx = {
          restartTriggers = [ config.systemd.services.nx-searxng-secret.serviceConfig.ExecStart ];
          serviceConfig.EnvironmentFile = allEnvFiles;
        };

        services.searx = {
          enable = true;
          settings = {
            use_default_settings = {
              engines.keep_only = [
                "brave"
                "brave.images"
                "brave.news"
              ]
              ++ extraDefaultEngines;
            };
            server = {
              port = port;
              bind_address = "127.0.0.1";
              secret_key = "$SEARXNG_SECRET_KEY";
            }
            // lib.optionalAttrs (domain != null && isExposed) {
              base_url = "https://${exposedSubdomain}.${domain}/";
            };
            search = {
              safe_search = 0;
              autocomplete = "brave";
              favicon_resolver = "duckduckgo";
            };
            ui.theme_args.simple_style = "black";
            preferences.lock = [
              "autocomplete"
              "center_alignment"
              "doi_resolver"
              "favicon_resolver"
              "image_proxy"
              "method"
              "query_in_title"
              "results_on_new_tab"
              "safesearch"
              "search_on_category_select"
              "simple_style"
              "theme"
            ];
          }
          // lib.optionalAttrs (extraEngines != [ ]) { engines = extraEngines; };
        };

        systemd.tmpfiles.settings."10-searxng" = {
          "/var/lib/searx".d = {
            mode = "0750";
            user = "searx";
            group = "searx";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}/var/lib/searx".d = {
            mode = "0750";
            user = "searx";
            group = "searx";
          };
        };
      };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.searxng;
          exposedSubdomain = if builtins.isString exposedService then exposedService else "search";
        in
        {
          nx.linux.server.dashboard.searchURL = lib.mkIf (
            domain != null && exposedService != false
          ) "https://${exposedSubdomain}.${domain}/search?q=";
          nx.linux.server.dashboard.suggestionURL = lib.mkIf (
            domain != null && exposedService != false
          ) "https://${exposedSubdomain}.${domain}/autocompleter?q=";
          nx.linux.server.dashboard.showSearchSuggestions = lib.mkIf (
            domain != null && exposedService != false
          ) true;
          nx.linux.server.dashboard.services = lib.optionals (domain != null && exposedService != false) [
            {
              name = "SearXNG";
              href = "https://${exposedSubdomain}.${domain}";
              description = "Privacy-respecting metasearch engine";
              icon = "searxng";
              group = "admin";
            }
          ];
        };
    };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          port,
          subdomain,
          fontFamily,
          squareCorners,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.searxng;
          exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;
          dashboardExposedService = self.host.remote.exposedServices.dashboard;
          dashboardSubdomain =
            if builtins.isString dashboardExposedService then
              dashboardExposedService
            else if config.nx.linux.server.dashboard.hostAtNginxSubdomain then
              config.nx.linux.server.nginx.subdomain
            else
              config.nx.linux.server.dashboard.subdomain;
          allowedCorsOrigins = lib.unique (
            lib.optional (
              config.nx.linux.server.dashboard.enable && dashboardExposedService != false
            ) "https://${dashboardSubdomain}.${domain}"
            ++ [ "https://${domain}" ]
          );
          corsExtraConfig =
            ''set $searxng_cors "";''
            + lib.concatMapStrings (o: ''
              if ($http_origin = "${o}") { set $searxng_cors $http_origin; }
            '') allowedCorsOrigins
            + "add_header Access-Control-Allow-Origin $searxng_cors always;";
          customCss = pkgs.writeText "searxng-custom.css" (
            lib.concatStrings [
              "body,html,main,#results,footer{background-color:#000!important}"
              (lib.optionalString (
                fontFamily != null
              ) "body,input,button,select,textarea{font-family:${fontFamily}!important}")
              (lib.optionalString squareCorners "*{border-radius:0!important}")
            ]
          );
        in
        lib.mkIf (exposedService != false) {
          services.nginx.virtualHosts."${exposedSubdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            extraConfig = ''
              sub_filter '</head>' '<link rel="stylesheet" href="/nx-custom.css"></head>';
              sub_filter_once on;
              proxy_set_header Accept-Encoding "";
            '';
            locations."= /nx-custom.css" = {
              alias = "${customCss}";
              extraConfig = ''add_header Content-Type "text/css";'';
            };
            locations."= /static/themes/simple/img/searxng.png".extraConfig = "empty_gif;";
            locations."/preferences" = {
              return = "302 https://${exposedSubdomain}.${domain}/";
            };
            locations."/info" = {
              return = "302 https://${exposedSubdomain}.${domain}/";
            };
            locations."/autocompleter" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              extraConfig = corsExtraConfig;
            };
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [
          "nx-searxng-secret.service"
          "searx.service"
        ];
        nx.linux.server.healthchecks.regularHealthChecks."+51 - SearXNG http reachable" = ''
          _code=$(${pkgs.curl}/bin/curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
            "http://localhost:${toString config.nx.linux.server.searxng.port}/" 2>/dev/null || true)
          printf 'http://localhost:${toString config.nx.linux.server.searxng.port}/ -> HTTP %s\n' "$_code" >&3
          [[ "$_code" =~ ^[23] ]]
        '';
      };
    };
  };
}
