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
  };

  module = {
    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        lib.mkIf (config.nx.linux.server.auth.baseUrl != null) {
          nx.linux.server.dashboard.services = [
            {
              name = config.nx.linux.server.auth.oidcProviderName;
              href = config.nx.linux.server.auth.baseUrl;
              description = "Single sign-on provider";
              icon = config.nx.linux.server.auth.oidcProviderId;
              group = "services";
            }
          ];
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
