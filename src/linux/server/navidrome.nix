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
  name = "navidrome";
  description = "Self-hosted music server";

  group = "server";
  input = "linux";

  submodules = { };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "music";
      description = "Subdomain for the nginx vhost.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4533;
      description = "Port navidrome listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/navidrome";
      description = "Directory for navidrome data and music library.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra settings passed to services.navidrome.settings.";
    };
  };

  module = {
    init =
      config:
      lib.mkIf config.nx.common.dev.claude.enable {
        nx.common.dev.claude.allowedWebFetchDomains = [ "navidrome\\.org" ];
      };

    enabled = config: {
      nx.packages.extra = [ pkgs.navidrome ];
    };

    linux.system =
      {
        config,
        subdomain,
        port,
        dataDir,
        extraSettings,
      }:
      {
        users.groups.navidrome-sync = { };
        users.users.navidrome.extraGroups = [ "navidrome-sync" ];

        services.navidrome = {
          enable = true;
          settings = {
            MusicFolder = "${dataDir}/music";
            DataFolder = dataDir;
            Port = port;
            Address = "127.0.0.1";
            EnableInsightsCollector = false;
          }
          // extraSettings;
        };

        systemd.tmpfiles.settings."navidromeDirs" = {
          "${dataDir}".d = lib.mkOverride 90 {
            mode = "0750";
            user = "navidrome";
            group = "navidrome-sync";
          };
          "${dataDir}/music".d = lib.mkOverride 90 {
            mode = "0750";
            user = "navidrome";
            group = "navidrome-sync";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${dataDir}".d = lib.mkOverride 90 {
            mode = "0750";
            user = "navidrome";
            group = "navidrome-sync";
          };
          "${self.persist}${dataDir}/music".d = lib.mkOverride 90 {
            mode = "0750";
            user = "navidrome";
            group = "navidrome-sync";
          };
        };

        environment.persistence = lib.mkIf self.host.impermanence {
          "${self.persist}".directories = [
            {
              directory = dataDir;
              user = "navidrome";
              group = "navidrome-sync";
              mode = "0750";
            }
          ];
        };
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          subdomain,
          port,
        }:
        let
          domain = self.host.remote.baseDomain;
        in
        lib.mkIf (domain != null) {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header Host $host;
              '';
            };
          };
        };
    };

    ifEnabled.linux.notifications.pushover = {
      linux.system =
        {
          config,
          dataDir,
          subdomain,
        }:
        let
          domain = self.host.remote.baseDomain;
          pushover = config.nx.linux.notifications.pushover;
        in
        lib.mkIf (domain != null && pushover.send != null) {
          systemd.services.navidrome-setup-notify = {
            description = "Notify about navidrome first-start admin setup";
            before = [ "navidrome.service" ];
            wantedBy = [ "navidrome.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = toString (
                pkgs.writeShellScript "navidrome-setup-notify" ''
                  if [ ! -f "${dataDir}/navidrome.db" ]; then
                    ${pushover.send {
                      title = "Navidrome";
                      message = "First start: visit https://${subdomain}.${domain} to create admin account.";
                    }}
                  fi
                ''
              );
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "navidrome.service" ];
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.navidrome;
          subdomain = config.nx.linux.server.navidrome.subdomain;
        in
        lib.mkIf (domain != null && exposedService != false) {
          nx.linux.server.dashboard.services = [
            {
              name = "Navidrome";
              href = "https://${subdomain}.${domain}";
              description = "Music server";
              icon = "navidrome";
              group = "services";
            }
          ];
        };
    };
  };
}
