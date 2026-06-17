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
let
  oidcIntegrations = [
    {
      moduleName = "paperless-ngx";
      clientName = "Paperless";
      allowedUserGroup = "paperless-users";
      callbackPath = "/accounts/oidc/{providerId}/login/callback/";
      pkceEnabled = true;
    }
  ];
in
{
  name = "auth";
  group = "server";
  input = "linux";
  description = "OIDC authentication provider interface";

  submodules = {
    linux.server.pocket-id = true;
  };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "auth";
      description = "Subdomain under baseDomain where the auth provider is served.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Full base URL of the OIDC provider, set by the implementation module.";
    };

    oidcDiscoveryUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Full OIDC discovery endpoint URL, set by the implementation module.";
    };

    oidcProviderName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Display name of the OIDC provider shown to end users, set by the implementation module.";
    };

    oidcProviderId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Provider slug used in callback URLs, set by the implementation module.";
    };

    logoutUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "URL users are redirected to after logout, set by the implementation module.";
    };

    enforceOIDC = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When true, all connected services disable regular login and require OIDC authentication, unless the service sets disableOIDCEnforcement = true.";
    };

    enableOAuthProxy = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Deploy an OIDC-backed oauth2-proxy to protect services without native OIDC support.";
    };

    oauthProxySubdomain = lib.mkOption {
      type = lib.types.str;
      default = "proxy";
      description = "Subdomain under baseDomain hosting the oauth2-proxy sign-in and callback endpoints.";
    };

    proxyProtectedVhosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Virtual hosts to protect via oauth2-proxy, each either a bare subdomain name under baseDomain or a fully qualified domain name.";
    };

    clients = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name shown in the OIDC provider UI for this client.";
            };
            callbackUrls = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Allowed redirect URIs for this OIDC client.";
            };
            allowedUserGroup = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "LDAP group name restricting access to this client, or null for all users.";
            };
            launchUrl = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "URL shown as the launch button for this client in the auth provider UI.";
            };
            pkceEnabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether PKCE is required for this OIDC client.";
            };
          };
        }
      );
      default = { };
      description = "OIDC clients managed declaratively by the active provider, keyed by service name.";
    };

  };

  module = {
    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        lib.mkIf (config.nx.linux.server.auth.baseUrl != null) {
          nx.linux.server.dashboard.services = lib.mkOrder 0 [
            {
              name = if config.nx.linux.server.auth.enableOAuthProxy then "Pocket ID" else "Login";
              href = config.nx.linux.server.auth.baseUrl;
              description = "Single sign-on provider";
              icon = if config.nx.linux.server.auth.enableOAuthProxy then "pocket-id" else "bitwarden";
              group = if config.nx.linux.server.auth.enableOAuthProxy then "admin" else "services";
            }
          ];
          nx.linux.server.dashboard.bookmarks = lib.mkIf config.nx.linux.server.auth.enableOAuthProxy (
            lib.mkOrder 0 [
              {
                name = "Login";
                href = config.nx.linux.server.auth.baseUrl;
                icon = "bitwarden";
                group = "links";
                description = "Manage passkeys and account settings";
              }
            ]
          );
          nx.linux.server.dashboard.customCSS = lib.mkOrder 2000 (
            ''
              li.service[data-name="Login"] .service-card {
                background-color: color-mix(in srgb, rgb(var(--color-100) / 0.65) 88%, white) !important;
                box-shadow: 0 10px 30px rgb(0 0 0 / 0.28);
              }

              .dark li.service[data-name="Login"] .service-card {
                background-color: color-mix(
                  in srgb,
                  rgb(var(--color-700) / 0.4) 88%,
                  white
                ) !important;
              }

              li.service[data-name="Login"] .service-card::after {
                content: "";
                position: absolute;
                inset: 3px;
                border-radius: inherit;
                box-shadow:
                  inset 0 0 0 2px rgb(255 255 255 / 0.20),
                  inset 0 0 24px rgb(255 255 255 / 0.08);
                pointer-events: none;
              }
            ''
            + lib.optionalString config.nx.linux.server.auth.enableOAuthProxy ''

              li.bookmark[data-name="Login"] a {
                position: relative;
                background-color: color-mix(in srgb, rgb(var(--color-100) / 0.65) 88%, white) !important;
                box-shadow: 0 10px 30px rgb(0 0 0 / 0.28);
              }

              .dark li.bookmark[data-name="Login"] a {
                background-color: color-mix(
                  in srgb,
                  rgb(var(--color-700) / 0.4) 88%,
                  white
                ) !important;
              }

              li.bookmark[data-name="Login"] a::after {
                content: "";
                position: absolute;
                inset: 3px;
                border-radius: inherit;
                box-shadow:
                  inset 0 0 0 2px rgb(255 255 255 / 0.20),
                  inset 0 0 24px rgb(255 255 255 / 0.08);
                pointer-events: none;
              }
            ''
          );
        };
    };

    enabled =
      config:
      let
        domain = self.host.remote.baseDomain;

        mkServiceConfig =
          svc:
          let
            svcCfg = config.nx.linux.server.${svc.moduleName};
            active = svcCfg.enable && svcCfg.enableOIDC;
            sub = svcCfg.subdomain;
          in
          lib.mkMerge [
            {
              nx.linux.server.auth.clients.${svc.moduleName} = lib.mkIf (active && domain != null) {
                name = svc.clientName;
                callbackUrls = [ "https://${sub}.${domain}${svc.callbackPath}" ];
                allowedUserGroup = svc.allowedUserGroup;
                launchUrl = "https://${sub}.${domain}";
                pkceEnabled = svc.pkceEnabled;
              };
            }
            {
              nx.linux.server.${svc.moduleName}.oidcConfiguration = lib.mkIf active {
                providerId = config.nx.linux.server.auth.oidcProviderId;
                providerName = config.nx.linux.server.auth.oidcProviderName;
                serverUrl = config.nx.linux.server.auth.baseUrl;
                logoutUrl = config.nx.linux.server.auth.logoutUrl;
                enforceOIDC = config.nx.linux.server.auth.enforceOIDC && !svcCfg.disableOIDCEnforcement;
              };
            }
          ];
      in
      lib.mkMerge (
        map mkServiceConfig oidcIntegrations
        ++ [
          (lib.mkIf (config.nx.linux.server.auth.enableOAuthProxy && domain != null) {
            nx.linux.server.auth.clients.oauth-proxy = {
              name = "Proxy";
              callbackUrls = [
                "https://${config.nx.linux.server.auth.oauthProxySubdomain}.${domain}/oauth2/callback"
              ];
              allowedUserGroup = null;
              launchUrl = null;
              pkceEnabled = true;
            };
          })
        ]
      );

    ifEnabled.linux.server.ldap = {
      linux.system = config: {
        assertions = lib.concatMap (
          entry:
          lib.optional (entry.allowedUserGroup != null) {
            assertion = builtins.elem entry.allowedUserGroup config.nx.linux.server.ldap.groups;
            message = "linux.server.auth: client '${entry.name}' references LDAP group '${entry.allowedUserGroup}' which is not declared in linux.server.ldap.groups!";
          }
        ) (lib.attrValues config.nx.linux.server.auth.clients);
      };
    };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          enableOAuthProxy,
          oauthProxySubdomain,
          proxyProtectedVhosts,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          hostname = self.host.hostname;
          exposedService = self.host.remote.exposedServices.proxy;
          exposedSubdomain = if builtins.isString exposedService then exposedService else oauthProxySubdomain;
          proxyDomain = "${exposedSubdomain}.${domain}";
          cookieSetupScript = pkgs.writeShellScript "nx-oauth2-proxy-cookie" ''
            set -euo pipefail
            if [ ! -f /var/lib/oauth2-proxy/cookie-secret ]; then
              ${pkgs.openssl}/bin/openssl rand -base64 24 \
                > /var/lib/oauth2-proxy/cookie-secret
              ${pkgs.coreutils}/bin/chmod 600 /var/lib/oauth2-proxy/cookie-secret
            fi
          '';

          envBuildScript = pkgs.writeShellScript "nx-oauth2-proxy-env" ''
            set -euo pipefail
            umask 077
            {
              printf 'OAUTH2_PROXY_CLIENT_ID='
              ${pkgs.coreutils}/bin/tr -d '\n' \
                < ${lib.escapeShellArg config.sops.secrets."${hostname}-oauth-proxy-client-id".path}
              printf '\n'
              printf 'OAUTH2_PROXY_CLIENT_SECRET='
              ${pkgs.coreutils}/bin/tr -d '\n' \
                < ${lib.escapeShellArg config.sops.secrets."${hostname}-oauth-proxy-client-secret".path}
              printf '\n'
              printf 'OAUTH2_PROXY_COOKIE_SECRET='
              ${pkgs.coreutils}/bin/tr -d '\n' < /var/lib/oauth2-proxy/cookie-secret
              printf '\n'
            } > /run/oauth2-proxy/env
          '';
        in
        lib.mkIf (enableOAuthProxy && domain != null && exposedService != false) {
          assertions = [
            {
              assertion = config.nx.linux.security.letsencrypt.enable;
              message = "linux.server.auth: enableOAuthProxy requires linux.security.letsencrypt to be enabled!";
            }
            {
              assertion = exposedSubdomain == oauthProxySubdomain;
              message = "linux.server.auth: oauthProxySubdomain '${oauthProxySubdomain}' does not match exposedServices.proxy subdomain '${exposedSubdomain}'!";
            }
          ];

          sops.secrets."${hostname}-oauth-proxy-client-id" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "oauth-proxy-client-id";
            owner = "root";
            mode = "0400";
          };

          sops.secrets."${hostname}-oauth-proxy-client-secret" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "oauth-proxy-client-secret";
            owner = "root";
            mode = "0400";
          };

          systemd.tmpfiles.settings."nx-oauth2-proxy" = {
            "/run/oauth2-proxy".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
            "/var/lib/oauth2-proxy".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
          }
          // lib.optionalAttrs self.host.impermanence {
            "${self.persist}/var/lib/oauth2-proxy".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
          };

          environment.persistence."${self.persist}" = {
            directories = [ "/var/lib/oauth2-proxy" ];
          };

          systemd.services.nx-oauth2-proxy-cookie = {
            description = "OAuth2 proxy cookie secret initialization";
            before = [ "nx-oauth2-proxy-env.service" ];
            wantedBy = [ "nx-oauth2-proxy-env.service" ];
            partOf = [ "nx-oauth2-proxy-env.service" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = toString cookieSetupScript;
            };
          };

          systemd.services.nx-oauth2-proxy-env = {
            description = "OAuth2 proxy environment assembly";
            after = [ "nx-oauth2-proxy-cookie.service" ];
            requires = [ "nx-oauth2-proxy-cookie.service" ];
            before = [ "oauth2-proxy.service" ];
            wantedBy = [ "oauth2-proxy.service" ];
            partOf = [ "oauth2-proxy.service" ];
            restartTriggers = [
              config.sops.secrets."${hostname}-oauth-proxy-client-id".sopsFile
              config.sops.secrets."${hostname}-oauth-proxy-client-secret".sopsFile
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = toString envBuildScript;
            };
          };

          services.oauth2-proxy = {
            enable = true;
            provider = "oidc";
            oidcIssuerUrl = config.nx.linux.server.auth.baseUrl;
            redirectURL = "https://${proxyDomain}/oauth2/callback";
            scope = "openid email profile groups";
            reverseProxy = true;
            setXauthrequest = true;
            email.domains = [ "*" ];
            cookie = {
              domain = ".${domain}";
              secure = true;
              httpOnly = true;
            };
            keyFile = "/run/oauth2-proxy/env";
            extraConfig = {
              code-challenge-method = "S256";
              trusted-proxy-ip = [
                "127.0.0.1"
                "::1"
              ];
              whitelist-domain = ".${domain}";
              insecure-oidc-allow-unverified-email = true;
            };
          };

          services.oauth2-proxy.nginx = {
            domain = proxyDomain;
            virtualHosts = builtins.listToAttrs (
              map (
                v:
                lib.nameValuePair (if builtins.match ".*\\..*" v != null then v else "${v}.${domain}") {
                  allowed_groups = [ "ldap-users" ];
                }
              ) (lib.unique proxyProtectedVhosts)
            );
          };

          services.nginx.virtualHosts.${proxyDomain} = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              return = "302 /oauth2/sign_in";
            };
          };

          systemd.services.oauth2-proxy = {
            after = [ "nx-oauth2-proxy-env.service" ];
            bindsTo = [ "nx-oauth2-proxy-env.service" ];
          };
        };
    };

    linux.system = config: {
      assertions = [
        {
          assertion = config.nx.linux.server.auth.baseUrl != null;
          message = "linux.server.auth is enabled but no provider has set auth.baseUrl!";
        }
        {
          assertion = config.nx.linux.server.auth.oidcDiscoveryUrl != null;
          message = "linux.server.auth is enabled but no provider has set auth.oidcDiscoveryUrl!";
        }
        {
          assertion = config.nx.linux.server.auth.oidcProviderName != null;
          message = "linux.server.auth is enabled but no provider has set auth.oidcProviderName!";
        }
        {
          assertion = config.nx.linux.server.auth.oidcProviderId != null;
          message = "linux.server.auth is enabled but no provider has set auth.oidcProviderId!";
        }
        {
          assertion = config.nx.linux.server.auth.logoutUrl != null;
          message = "linux.server.auth is enabled but no provider has set auth.logoutUrl!";
        }
      ];
    };
  };
}
