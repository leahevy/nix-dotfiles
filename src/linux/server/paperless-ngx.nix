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
  };

  module = {
    enabled = config: {
      nx.linux.server.postgresql.connectionSlots = [ 60 ];
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          service = "redis-paperless.service";
          string = "Redis does not require authentication";
        }
      ];
    };

    linux.system =
      {
        config,
        subdomain,
        ocrLanguage,
        paperlessDataBasePath,
        importPublic,
        adminUser,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        basePath = paperlessDataBasePath;
        exposedService = self.host.remote.exposedServices.paperless-ngx;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else "paperless-ngx";
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
        ];

        environment.persistence."${self.persist}" = {
          directories = [ basePath ];
        };

        sops.secrets."${self.host.hostname}-paperless-admin-pass" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "paperless-admin-pass";
          owner = "paperless";
          group = "paperless";
          mode = "0400";
        };

        systemd.tmpfiles.settings."10-paperless-export"."${basePath}/export".d = {
          mode = "0750";
          user = "paperless";
          group = "paperless";
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
          };
        };
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

    ifEnabled.linux.server.auth = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          subdomain = config.nx.linux.server.paperless-ngx.subdomain;
          providerId = config.nx.linux.server.auth.oidcProviderId;
        in
        {
          nx.linux.server.auth.clients.paperless =
            lib.mkIf (config.nx.linux.server.paperless-ngx.enableOIDC && domain != null && providerId != null)
              {
                name = "Paperless";
                callbackUrls = [
                  "https://${subdomain}.${domain}/accounts/oidc/${providerId}/login/callback/"
                ];
                allowedUserGroup = "paperless";
              };
        };

      linux.system =
        {
          config,
          enableOIDC,
          disableOIDCEnforcement,
          ...
        }:
        let
          auth = config.nx.linux.server.auth;
          enforcing = auth.enforceOIDC && !disableOIDCEnforcement && enableOIDC;
          serverUrl = if auth.baseUrl != null then auth.baseUrl else "";
          providerId = if auth.oidcProviderId != null then auth.oidcProviderId else "";
          providerName = if auth.oidcProviderName != null then auth.oidcProviderName else "";
        in
        lib.mkMerge [
          (lib.optionalAttrs enableOIDC {
            assertions = [
              {
                assertion = auth.baseUrl != null;
                message = "linux.server.paperless-ngx: enableOIDC requires auth.baseUrl to be set by the active provider!";
              }
            ];

            sops.secrets."paperless-oidc-id" = {
              format = "binary";
              sopsFile = self.profile.secretsPath "paperless-oidc-id";
              owner = "root";
              mode = "0400";
            };

            sops.secrets."paperless-oidc-secret" = {
              format = "binary";
              sopsFile = self.profile.secretsPath "paperless-oidc-secret";
              owner = "root";
              mode = "0400";
            };

            systemd.tmpfiles.settings."paperless-oidc" = {
              "/run/paperless-oidc".d = {
                mode = "0700";
                user = "root";
                group = "root";
              };
            };

            systemd.services.nx-paperless-oidc-prep = {
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
                      printf 'PAPERLESS_SOCIALACCOUNT_PROVIDERS='
                      ${pkgs.jq}/bin/jq -cn \
                        --rawfile cid_raw ${lib.escapeShellArg config.sops.secrets."paperless-oidc-id".path} \
                        --rawfile secret_raw ${lib.escapeShellArg config.sops.secrets."paperless-oidc-secret".path} \
                        --arg pid ${lib.escapeShellArg providerId} \
                        --arg pname ${lib.escapeShellArg providerName} \
                        --arg url ${lib.escapeShellArg serverUrl} \
                        '{"openid_connect":{"APPS":[{"provider_id":$pid,"name":$pname,"client_id":($cid_raw|rtrimstr("\n")),"secret":($secret_raw|rtrimstr("\n")),"settings":{"server_url":$url}}]}}'
                    } >> /run/paperless-oidc/providers.env
                    ${pkgs.coreutils}/bin/chmod 600 /run/paperless-oidc/providers.env
                  ''
                );
              };
            };

            services.paperless.settings = {
              PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
              PAPERLESS_SOCIALACCOUNT_ALLOW_SIGNUPS = "true";
              PAPERLESS_SOCIAL_AUTO_SIGNUP = "true";
            }
            // lib.optionalAttrs (auth.logoutUrl != null) {
              PAPERLESS_LOGOUT_REDIRECT_URL = auth.logoutUrl;
            };

            services.paperless.environmentFile = "/run/paperless-oidc/providers.env";

            systemd.services.paperless-web = {
              after = [ "nx-paperless-oidc-prep.service" ];
              requires = [ "nx-paperless-oidc-prep.service" ];
            };
          })

          (lib.optionalAttrs enforcing {
            services.paperless.settings = {
              PAPERLESS_DISABLE_REGULAR_LOGIN = "true";
              PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
            };
          })
        ];
    };
  };
}
