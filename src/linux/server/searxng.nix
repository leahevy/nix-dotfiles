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

    maxShownResultLines = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 3;
      description = "Maximum number of lines shown for result content previews, or null to show the full content.";
    };

    injectSearchURL = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = "Set the dashboard search URL to this SearXNG instance when the dashboard module is enabled, or null to auto-enable when enableCustomBraveSearch is true.";
    };

    injectSuggestionURL = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set the dashboard suggestion URL to the SearXNG autocomplete endpoint when the dashboard module is enabled.";
    };

    title = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Short text rendered as the instance icon, or null to suppress the default branding.";
    };

    titleColor = lib.mkOption {
      type = lib.types.str;
      default = "white";
      description = "CSS color applied to the title text in the generated icon.";
    };

    titleFontSize = lib.mkOption {
      type = lib.types.int;
      default = 48;
      description = "Font size in SVG units used for the title text in the generated icon.";
    };

    engines = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Search engines to load and enable, keyed by SearXNG engine name, merged over the built-in engines.";
    };

    extraSecrets = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables written to the SearXNG env file, keyed by variable name with the SOPS decrypted file path as value.";
    };

    blockedHostnames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Plain domain names whose results are removed from all searches (e.g. example.com).";
    };

    enableCustomBraveSearch = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Brave Search API engine using the searxng-brave-api-key SOPS secret.";
    };
  };

  module = {
    enabled = config: {
      nx.packages.extra = [ pkgs.searxng ];
    };

    linux.system =
      {
        config,
        port,
        subdomain,
        engines,
        extraSecrets,
        blockedHostnames,
        enableCustomBraveSearch,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        exposedService = self.host.remote.exposedServices.searxng;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;
        envFile = "/run/nx-searxng-env/env";
        allExtraSecrets =
          lib.optionalAttrs enableCustomBraveSearch {
            "BRAVE_API_KEY" = config.sops.secrets."searxng-brave-api-key".path;
          }
          // extraSecrets;
        baseEngines = {
          wikipedia = {
            categories = [
              "general"
              "web"
            ];
          };
          "nixos wiki" = {
            weight = 0.2;
            categories = [
              "general"
              "nix"
            ];
          };
        }
        // lib.optionalAttrs enableCustomBraveSearch {
          braveapi = {
            api_key = "$BRAVE_API_KEY";
            inactive = false;
            categories = [
              "general"
              "web"
            ];
          };
        };
        allEngines = baseEngines // engines;
        derivedCategories = lib.foldlAttrs (
          acc: _: engine:
          acc // lib.genAttrs (engine.categories or [ ]) (_: { })
        ) { } allEngines;
        allCategories = derivedCategories;
        enginesList = lib.mapAttrsToList (
          name: engine:
          {
            inherit name;
            disabled = false;
          }
          // (builtins.removeAttrs engine [ "categories" ])
          // lib.optionalAttrs (engine ? categories) { categories = engine.categories; }
        ) allEngines;
      in
      {
        assertions = [
          {
            assertion = domain != null;
            message = "linux.server.searxng requires host.remote.baseDomain to be set!";
          }
          {
            assertion = builtins.all (
              d: builtins.match "[a-zA-Z0-9][a-zA-Z0-9.-]*\\.[a-zA-Z0-9]+" d != null
            ) blockedHostnames;
            message = "linux.server.searxng: blockedHostnames entries must be plain domain names (e.g. example.com)!";
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

        sops.secrets = lib.optionalAttrs enableCustomBraveSearch {
          "searxng-brave-api-key" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "searxng-brave-api-key";
            mode = "0400";
            owner = "searx";
            group = "searx";
          };
        };

        environment.persistence."${self.persist}" = {
          directories = [ "/var/lib/searx" ];
        };

        systemd.services.nx-searxng-secret = {
          description = "Prepare SearXNG secret key environment";
          before = [ "searx-init.service" ];
          wantedBy = [ "searx-init.service" ];
          partOf = [ "searx-init.service" ];
          restartTriggers = lib.optionals enableCustomBraveSearch [
            config.sops.secrets."searxng-brave-api-key".sopsFile
          ];
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
                  ${lib.concatStrings (
                    lib.mapAttrsToList (envVar: secretPath: ''
                      printf '${envVar}='
                      ${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg secretPath}
                      printf '\n'
                    '') allExtraSecrets
                  )}
                } > /run/nx-searxng-env/env
              ''
            );
          };
        };

        systemd.services.searx-init = {
          after = [ "nx-searxng-secret.service" ];
          bindsTo = [ "nx-searxng-secret.service" ];
          restartTriggers = [ config.systemd.services.nx-searxng-secret.serviceConfig.ExecStart ];
          serviceConfig.EnvironmentFile = envFile;
        };

        systemd.services.searx = {
          restartTriggers = [ config.systemd.services.nx-searxng-secret.serviceConfig.ExecStart ];
          serviceConfig.EnvironmentFile = envFile;
        };

        services.searx = {
          enable = true;
          settings = {
            use_default_settings = {
              engines.keep_only = lib.attrNames allEngines;
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
            categories_as_tabs = allCategories;
            engines = enginesList;
          }
          // lib.optionalAttrs (blockedHostnames != [ ]) {
            hostnames.remove = map (d: "(.*\\.)?${lib.replaceStrings [ "." ] [ "\\." ] d}$") blockedHostnames;
          };
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
          rawInjectSearch = config.nx.linux.server.searxng.injectSearchURL;
          effectiveInjectSearch =
            if rawInjectSearch != null then
              rawInjectSearch
            else
              config.nx.linux.server.searxng.enableCustomBraveSearch;
        in
        {
          nx.linux.server.dashboard.searchURL = lib.mkIf (
            effectiveInjectSearch && domain != null && exposedService != false
          ) "https://${exposedSubdomain}.${domain}/search?q=";
          nx.linux.server.dashboard.suggestionURL = lib.mkIf (
            config.nx.linux.server.searxng.injectSuggestionURL && domain != null && exposedService != false
          ) "https://${exposedSubdomain}.${domain}/autocompleter?q=";
          nx.linux.server.dashboard.showSearchSuggestions = lib.mkIf (
            config.nx.linux.server.searxng.injectSuggestionURL && domain != null && exposedService != false
          ) true;
          nx.linux.server.dashboard.services = lib.mkOrder 10 (
            lib.optionals (domain != null && exposedService != false) [
              {
                name = "Search";
                href = "https://${exposedSubdomain}.${domain}";
                description = "Wiki and internal search";
                icon = "searxng";
                group = if effectiveInjectSearch then "admin" else "services";
              }
            ]
          );
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
          maxShownResultLines,
          title,
          titleColor,
          titleFontSize,
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
              (lib.optionalString (maxShownResultLines != null)
                "p.content{overflow:hidden;display:-webkit-box;-webkit-line-clamp:${toString maxShownResultLines};-webkit-box-orient:vertical}"
              )
              (lib.optionalString (
                fontFamily != null
              ) "body,input,button,select,textarea{font-family:${fontFamily}!important}")
              (lib.optionalString squareCorners "*{border-radius:0!important}")
            ]
          );
          iconSvg =
            if title != null then
              pkgs.writeText "searxng-icon.svg" ''
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${
                  toString ((builtins.stringLength title + 2) * titleFontSize)
                } ${toString (titleFontSize + 16)}">
                  <text x="50%" y="50%" dominant-baseline="central" text-anchor="middle"
                        font-family="monospace" font-size="${toString titleFontSize}" fill="${titleColor}">${title}</text>
                </svg>
              ''
            else
              null;
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
            locations."= /static/themes/simple/img/searxng.png" =
              if iconSvg == null then
                { extraConfig = "empty_gif;"; }
              else
                {
                  alias = "${iconSvg}";
                  extraConfig = ''add_header Content-Type "image/svg+xml";'';
                };
            locations."/preferences" = {
              return = "302 https://${exposedSubdomain}.${domain}/";
            };
            locations."/info" = {
              return = "302 https://${exposedSubdomain}.${domain}/";
            };
            locations."/autocompleter" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              recommendedProxySettings = false;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              ''
              + corsExtraConfig;
            };
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              recommendedProxySettings = false;
              extraConfig = ''
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
              '';
            };
          };
        };
    };

    ifEnabled.linux.server.auth = {
      enabled =
        config:
        let
          exposedService = self.host.remote.exposedServices.searxng;
        in
        lib.mkIf (config.nx.linux.server.auth.enableOAuthProxy && exposedService != false) {
          nx.linux.server.auth.proxyProtectedVhosts = [ config.nx.linux.server.searxng.subdomain ];
        };
      linux.system =
        { config, subdomain, ... }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.searxng;
          exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;
        in
        lib.mkIf (config.nx.linux.server.auth.enableOAuthProxy && exposedService != false && domain != null)
          {
            services.nginx.virtualHosts."${exposedSubdomain}.${domain}".locations."/autocompleter".extraConfig =
              "auth_request off;";
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
            -H "X-Real-IP: 127.0.0.1" \
            "http://localhost:${toString config.nx.linux.server.searxng.port}/" 2>/dev/null || true)
          printf 'http://localhost:${toString config.nx.linux.server.searxng.port}/ -> HTTP %s\n' "$_code" >&3
          [[ "$_code" =~ ^[23] ]]
        '';
      };
    };
  };
}
