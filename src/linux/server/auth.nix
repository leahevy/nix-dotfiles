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
            sopsSecretPath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Runtime path of the SOPS-decrypted secret file for this client, set by the consuming service module.";
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
        lib.mkIf (config.nx.linux.server.auth.enable && config.nx.linux.server.auth.baseUrl != null) {
          nx.linux.server.dashboard.services = lib.mkOrder 0 [
            {
              name = "Login";
              href = config.nx.linux.server.auth.baseUrl;
              description = "Single sign-on provider";
              icon = "bitwarden";
              group = "services";
            }
          ];
          nx.linux.server.dashboard.customCSS = lib.mkOrder 2000 ''
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
          '';
        };
    };

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
