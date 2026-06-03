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
  name = "syncthing";
  description = "Syncthing file synchronisation server service";

  group = "server";
  input = "linux";

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "syncthing";
      description = "Subdomain under baseDomain where the Syncthing GUI is served.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/syncthing";
      description = "Directory for Syncthing data and configuration.";
    };

    guiPort = lib.mkOption {
      type = lib.types.int;
      default = 8384;
      description = "Local port the Syncthing GUI listens on.";
    };

    guiUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Username for the Syncthing GUI login.";
    };

    devices = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name for this Syncthing device.";
            };
            id = lib.mkOption {
              type = lib.types.str;
              description = "Syncthing device ID.";
            };
            addresses = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Explicit addresses for this device, e.g. tcp://192.168.1.100:22000. Empty means inbound-only.";
            };
          };
        }
      );
      default = [ ];
      description = "List of Syncthing devices to declare, each with name and id fields.";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 22000;
      description = "Port used for both TCP and QUIC sync listeners.";
    };

    enableTCP = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to listen for incoming sync connections over TCP.";
    };

    enableQuic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to listen for incoming sync connections over QUIC.";
    };

    listenHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "0.0.0.0" ];
      description = "IP addresses to bind the sync listeners to.";
    };

    paperlessIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to auto-configure shared access to paperless import and export directories when paperless-ngx is enabled.";
    };
  };

  module = {
    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "syncthing.service" ];
        nx.linux.server.healthchecks.loadHighCpuExemptCommands = [ "syncthing" ];
      };
    };

    linux.system =
      {
        config,
        subdomain,
        dataDir,
        guiPort,
        guiUser,
        devices,
        port,
        enableTCP,
        enableQuic,
        listenHosts,
        ...
      }:
      let
        domain = self.host.remote.baseDomain;
        exposedService = self.host.remote.exposedServices.syncthing;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else "syncthing";
        devicesAttr = builtins.listToAttrs (
          map (d: {
            name = d.name;
            value = {
              id = d.id;
            }
            // lib.optionalAttrs (d.addresses != [ ]) {
              addresses = d.addresses;
            };
          }) devices
        );
        listenAddresses = lib.flatten (
          map (
            host:
            lib.optionals enableTCP [ "tcp://${host}:${toString port}" ]
            ++ lib.optionals enableQuic [ "quic://${host}:${toString port}" ]
          ) listenHosts
        );
      in
      {
        assertions = [
          {
            assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.syncthing requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = domain != null;
            message = "linux.server.syncthing requires host.remote.baseDomain to be set!";
          }
          {
            assertion = exposedService == false || exposedSubdomain == subdomain;
            message = "linux.server.syncthing: subdomain '${subdomain}' does not match exposedServices.syncthing subdomain '${exposedSubdomain}'!";
          }
          {
            assertion = enableTCP || enableQuic;
            message = "linux.server.syncthing: at least one of enableTCP or enableQuic must be true!";
          }
        ];

        environment.persistence."${self.persist}" = {
          directories = [ dataDir ];
        };

        sops.secrets."${self.host.hostname}-syncthing-gui-pass" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing-gui-pass";
          owner = "syncthing";
          mode = "0400";
        };

        sops.secrets."${self.host.hostname}-syncthing-server-key" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing-server.key";
          owner = "syncthing";
          mode = "0400";
        };

        sops.secrets."${self.host.hostname}-syncthing-server-cert" = {
          format = "binary";
          sopsFile = self.profile.secretsPath "syncthing-server.cert";
          owner = "syncthing";
          mode = "0400";
        };

        services.syncthing = {
          enable = true;
          dataDir = dataDir;
          overrideDevices = false;
          overrideFolders = false;
          guiAddress = "127.0.0.1:${toString guiPort}";
          guiPasswordFile = config.sops.secrets."${self.host.hostname}-syncthing-gui-pass".path;
          key = config.sops.secrets."${self.host.hostname}-syncthing-server-key".path;
          cert = config.sops.secrets."${self.host.hostname}-syncthing-server-cert".path;
          settings = {
            devices = devicesAttr;
            options = {
              urAccepted = -1;
              relaysEnabled = false;
              natEnabled = false;
              localAnnounceEnabled = false;
              globalAnnounceEnabled = false;
              listenAddresses = listenAddresses;
            };
            gui.user = guiUser;
          };
        };

        networking.firewall = lib.mkIf config.nx.linux.networking.firewall.enable {
          allowedTCPPorts = lib.optionals enableTCP [ port ];
          allowedUDPPorts = lib.optionals enableQuic [ port ];
        };
      };

    ifEnabled.linux.services.fail2ban = {
      linux.system = config: {
        services.fail2ban.jails.nginx-syncthing-auth = {
          filter = {
            Definition = {
              failregex = ''^\S+ nginx: <HOST> - - \[.+\] "POST /rest/noauth/auth/password HTTP/\S+" 403 \S+ "https://${config.nx.linux.server.syncthing.subdomain}.${self.host.remote.baseDomain}/'';
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
        {
          config,
          subdomain,
          guiPort,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.syncthing;
        in
        lib.mkIf (exposedService != false) {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString guiPort}";
              proxyWebsockets = true;
              recommendedProxySettings = false;
              extraConfig = ''
                proxy_set_header Host "localhost:${toString guiPort}";
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Host $host;
                proxy_set_header X-Forwarded-Server $hostname;
                proxy_read_timeout 600s;
                proxy_send_timeout 600s;
              '';
            };
          };
        };
    };

    when = {
      option.paperlessIntegration = true;
      modules.linux.server.paperless-ngx = true;
      do.linux.system =
        { config, ... }:
        let
          basePath = config.nx.linux.server.paperless-ngx.paperlessDataBasePath;
        in
        {
          users.groups.paperless-sync = { };
          users.users.syncthing.extraGroups = [ "paperless-sync" ];
          users.users.paperless.extraGroups = [ "paperless-sync" ];

          systemd.tmpfiles.settings."10-paperless"."${basePath}/import".d = lib.mkForce {
            mode = "2770";
            user = "paperless";
            group = "paperless-sync";
          };
          systemd.tmpfiles.settings."10-paperless-export"."${basePath}/export".d = lib.mkForce {
            mode = "2770";
            user = "paperless";
            group = "paperless-sync";
          };

          services.syncthing.settings.folders = {
            "paperless-import" = {
              path = "${basePath}/import";
              label = "Paperless Import";
              devices = lib.attrNames config.services.syncthing.settings.devices;
            };
            "paperless-export" = {
              path = "${basePath}/export";
              label = "Paperless Export";
              devices = lib.attrNames config.services.syncthing.settings.devices;
            };
          };
        };
    };
  };
}
