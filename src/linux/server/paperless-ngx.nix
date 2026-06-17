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
  name = "paperless-ngx";
  description = "Paperless-ngx document management service";

  group = "server";
  input = "linux";

  submodules = {
    linux.server = [ "postgresql" ];
  };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "paperless";
      description = "Subdomain under baseDomain where paperless is served.";
    };

    ocrLanguage = lib.mkOption {
      type = lib.types.str;
      default = "deu+eng";
      description = "Tesseract OCR language codes used for document processing.";
    };

    paperlessDataBasePath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/paperless-ngx-data";
      description = "Base directory from which all paperless data subdirectories are derived.";
    };

    importPublic = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether all system users can write to the import directory.";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Username for the paperless superuser account.";
    };

    enableSearxng = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SearXNG integration for document search using the paperless-searxng SOPS secret containing the raw Paperless API token.";
    };

    enableOIDC = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OIDC authentication via the active auth provider.";
    };

    disableOIDCEnforcement = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Opt this service out of OIDC login enforcement even when linux.server.auth.enforceOIDC is true.";
    };

    oidcConfiguration = lib.mkOption {
      type = lib.types.submodule {
        options = {
          providerId = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Resolved OIDC provider id injected by the auth integration.";
          };
          providerName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Resolved OIDC provider display name injected by the auth integration.";
          };
          serverUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Resolved OIDC server URL injected by the auth integration.";
          };
          logoutUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Resolved logout redirect URL injected by the auth integration.";
          };
          enforceOIDC = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether Paperless should disable regular login and force SSO.";
          };
        };
      };
      default = { };
      description = "Resolved OIDC settings injected by the auth integration.";
    };
  };

  module = {
    linux.system =
      {
        config,
        subdomain,
        ocrLanguage,
        paperlessDataBasePath,
        importPublic,
        adminUser,
        enableOIDC,
        oidcConfiguration,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        basePath = paperlessDataBasePath;
        exposedService = self.host.remote.exposedServices.paperless-ngx;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else "paperless-ngx";
        providerId = oidcConfiguration.providerId;
        providerName = oidcConfiguration.providerName;
        serverUrl = oidcConfiguration.serverUrl;
        logoutUrl = oidcConfiguration.logoutUrl;
      in
      {
        assertions = [
          {
            assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.paperless-ngx requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = domain != null;
            message = "linux.server.paperless-ngx requires host.remote.baseDomain to be set!";
          }
          {
            assertion = exposedService == false || exposedSubdomain == subdomain;
            message = "linux.server.paperless-ngx: subdomain '${subdomain}' does not match exposedServices.paperless-ngx subdomain '${exposedSubdomain}'!";
          }
          {
            assertion = !enableOIDC || config.nx.linux.server.auth.enable;
            message = "linux.server.paperless-ngx: enableOIDC requires linux.server.auth to be enabled!";
          }
          {
            assertion = !enableOIDC || providerId != null;
            message = "linux.server.paperless-ngx: enableOIDC requires oidcConfiguration.providerId to be set by the auth integration!";
          }
          {
            assertion = !enableOIDC || providerName != null;
            message = "linux.server.paperless-ngx: enableOIDC requires oidcConfiguration.providerName to be set by the auth integration!";
          }
          {
            assertion = !enableOIDC || serverUrl != null;
            message = "linux.server.paperless-ngx: enableOIDC requires oidcConfiguration.serverUrl to be set by the auth integration!";
          }
        ];

        environment.persistence."${self.persist}" = {
          directories = [ basePath ];
        };

        sops.secrets = {
          "${self.host.hostname}-paperless-admin-pass" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "paperless-admin-pass";
            owner = "paperless";
            group = "paperless";
            mode = "0400";
          };

          "paperless-oidc-id" = lib.mkIf enableOIDC {
            format = "binary";
            sopsFile = self.profile.secretsPath "paperless-oidc-id";
            owner = "root";
            mode = "0400";
          };

          "paperless-oidc-secret" = lib.mkIf enableOIDC {
            format = "binary";
            sopsFile = self.profile.secretsPath "paperless-oidc-secret";
            owner = "root";
            mode = "0400";
          };

        };

        systemd.tmpfiles.settings."10-paperless-export" = {
          "${basePath}/export".d = {
            mode = "0750";
            user = "paperless";
            group = "paperless";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${basePath}".d = {
            mode = "0750";
            user = "paperless";
            group = "paperless";
          };
        };

        services.paperless = {
          enable = true;
          domain = if domain != null then "${subdomain}.${domain}" else null;
          database.createLocally = true;
          dataDir = "${basePath}/data";
          mediaDir = "${basePath}/media";
          consumptionDir = "${basePath}/import";
          consumptionDirIsPublic = importPublic;
          passwordFile = config.sops.secrets."${self.host.hostname}-paperless-admin-pass".path;
          exporter.directory = "${basePath}/export";
          settings = {
            PAPERLESS_OCR_LANGUAGE = ocrLanguage;
            PAPERLESS_ADMIN_USER = adminUser;
            PAPERLESS_CONSUMER_RECURSIVE = true;
            PAPERLESS_USE_X_FORWARD_HOST = true;
            PAPERLESS_PROXY_SSL_HEADER = [
              "HTTP_X_FORWARDED_PROTO"
              "https"
            ];
          }
          // lib.optionalAttrs enableOIDC {
            PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
            PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = "true";
            PAPERLESS_SOCIAL_AUTO_SIGNUP = "true";
          }
          // lib.optionalAttrs (enableOIDC && logoutUrl != null) {
            PAPERLESS_LOGOUT_REDIRECT_URL = logoutUrl;
          }
          // lib.optionalAttrs (enableOIDC && oidcConfiguration.enforceOIDC) {
            PAPERLESS_DISABLE_REGULAR_LOGIN = "true";
            PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
          };
        }
        // lib.optionalAttrs enableOIDC {
          environmentFile = "/run/paperless-oidc/providers.env";
        };

        systemd.tmpfiles.settings."paperless-oidc" = lib.mkIf enableOIDC {
          "/run/paperless-oidc".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
        };

        systemd.services = lib.mkMerge [
          {
            paperless-web.serviceConfig.TimeoutStopSec = 600;
            paperless-scheduler.serviceConfig.TimeoutStopSec = 600;
            paperless-task-queue.serviceConfig.TimeoutStopSec = 600;
            paperless-consumer.serviceConfig.TimeoutStopSec = 600;
            paperless-web.restartTriggers = [
              (builtins.toJSON config.users.users.paperless.extraGroups)
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless" or { }))
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless-export" or { }))
            ];
            paperless-scheduler.restartTriggers = [
              (builtins.toJSON config.users.users.paperless.extraGroups)
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless" or { }))
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless-export" or { }))
            ];
            paperless-task-queue.restartTriggers = [
              (builtins.toJSON config.users.users.paperless.extraGroups)
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless" or { }))
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless-export" or { }))
            ];
            paperless-consumer.restartTriggers = [
              (builtins.toJSON config.users.users.paperless.extraGroups)
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless" or { }))
              (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless-export" or { }))
            ];
          }
          (lib.mkIf enableOIDC {
            nx-paperless-oidc-prep = {
              description = "Prepare Paperless OIDC provider environment";
              before = [ "paperless-web.service" ];
              wantedBy = [ "paperless-web.service" ];
              partOf = [ "paperless-web.service" ];
              restartTriggers = [
                config.sops.secrets."paperless-oidc-id".sopsFile
                config.sops.secrets."paperless-oidc-secret".sopsFile
              ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = toString (
                  pkgs.writeShellScript "nx-paperless-oidc-prep" ''
                    set -euo pipefail
                    umask 077
                    ${pkgs.coreutils}/bin/rm -f /run/paperless-oidc/providers.env
                    ${pkgs.coreutils}/bin/touch /run/paperless-oidc/providers.env
                    {
                      printf "PAPERLESS_SOCIALACCOUNT_PROVIDERS='"
                      ${pkgs.jq}/bin/jq -cn \
                        --rawfile cid_raw ${lib.escapeShellArg config.sops.secrets."paperless-oidc-id".path} \
                        --rawfile secret_raw ${lib.escapeShellArg config.sops.secrets."paperless-oidc-secret".path} \
                        --arg pid ${lib.escapeShellArg providerId} \
                        --arg pname ${lib.escapeShellArg providerName} \
                        --arg url ${lib.escapeShellArg serverUrl} \
                        '{"openid_connect":{"APPS":[{"provider_id":$pid,"name":$pname,"client_id":($cid_raw|rtrimstr("\n")),"secret":($secret_raw|rtrimstr("\n")),"settings":{"server_url":$url,"oauth_pkce_enabled":true}}]}}'
                      printf "'"
                    } >> /run/paperless-oidc/providers.env
                    ${pkgs.coreutils}/bin/chmod 600 /run/paperless-oidc/providers.env
                  ''
                );
              };
            };

            paperless-web = {
              after = [ "nx-paperless-oidc-prep.service" ];
              bindsTo = [ "nx-paperless-oidc-prep.service" ];
            };
          })
        ];
      };

    ifEnabled.linux.services.fail2ban = {
      linux.system = config: {
        services.fail2ban.jails.nginx-paperless-auth = {
          filter = {
            Definition = {
              failregex = ''^\S+ nginx: <HOST> - - \[.+\] "POST /accounts/login/\S* HTTP/\S+" 200 \S+ "https://${config.nx.linux.server.paperless-ngx.subdomain}.${self.host.remote.baseDomain}/accounts/login/'';
              ignoreregex = "";
            };
          };
          settings = {
            backend = "systemd";
            journalmatch = "_SYSTEMD_UNIT=nginx.service";
            maxretry = 5;
            findtime = 600;
            bantime = 3600;
          };
        };
      };
    };

    ifEnabled.linux.server.nginx = {
      linux.system =
        { config, subdomain, ... }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.paperless-ngx;
        in
        lib.mkIf (exposedService != false) {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:28981";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
                client_max_body_size 50m;
              '';
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "paperless-web.service" ];
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.paperless-ngx;
          subdomain = config.nx.linux.server.paperless-ngx.subdomain;
        in
        lib.mkIf (domain != null && exposedService != false) {
          nx.linux.server.dashboard.services = [
            {
              name = "Paperless";
              href = "https://${subdomain}.${domain}";
              description = "Document management system";
              icon = "paperless-ngx";
              group = "services";
            }
          ];
        };
    };

    ifEnabled.linux.server.tika = {
      enabled = config: {
        nx.linux.server.tika.ocrLanguages =
          lib.splitString "+" config.nx.linux.server.paperless-ngx.ocrLanguage;
      };
    };

    ifEnabled.linux.server.searxng = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          paperlessExposed = self.host.remote.exposedServices."paperless-ngx";
          paperlessSubdomain =
            if builtins.isString paperlessExposed then
              paperlessExposed
            else
              config.nx.linux.server.paperless-ngx.subdomain;
          publicBase =
            if domain != null && paperlessExposed != false then
              "https://${paperlessSubdomain}.${domain}"
            else
              "http://127.0.0.1:28981";
        in
        {
          nx.linux.server.searxng.extraSecrets = lib.mkIf config.nx.linux.server.paperless-ngx.enableSearxng {
            "PAPERLESS_TOKEN" = config.sops.secrets."paperless-searxng".path;
          };
          nx.linux.server.searxng.engines = lib.mkIf config.nx.linux.server.paperless-ngx.enableSearxng {
            "Paperless" = {
              engine = "json_engine";
              shortcut = "plx";
              categories = [
                "paperless"
                "general"
              ];
              enable_http = true;
              search_url = "http://127.0.0.1:28981/api/documents/?query={query}";
              headers = {
                Authorization = "Token $PAPERLESS_TOKEN";
              };
              results_query = "results";
              title_query = "title";
              content_query = "content";
              url_query = "id";
              url_prefix = "${publicBase}/documents/";
              weight = 2;
              paging = false;
            };
          };
        };

      linux.system =
        { config, enableSearxng, ... }:
        lib.mkIf enableSearxng {
          sops.secrets."paperless-searxng" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "paperless-searxng";
            owner = "searx";
            group = "searx";
            mode = "0400";
          };
        };
    };

    enabled = config: {
      nx.linux.server.postgresql.connectionSlots = [ 60 ];
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          service = "redis-paperless.service";
          string = "Redis does not require authentication";
        }
      ];
      nx.packages.extra = [ pkgs.paperless-ngx ];
    };

  };
}
