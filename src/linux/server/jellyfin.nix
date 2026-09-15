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
  name = "jellyfin";
  description = "Self-hosted media streaming server";

  group = "server";
  input = "linux";

  submodules = { };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "media";
      description = "Subdomain for the nginx vhost.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "Port jellyfin listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/jellyfin";
      description = "Directory for jellyfin data and media library.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra settings merged into services.jellyfin.";
    };

    extraMediaPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "/mnt/jellyfin";
      description = "Optional extra media path created at boot and readable by jellyfin, e.g. for a USB drive.";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8920;
      description = "HTTPS port jellyfin listens on.";
    };

    enableRemoteAccess = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow remote access from outside the local network.";
    };

    localNetworkSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Subnets treated as local by jellyfin.";
    };

    knownProxies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional known proxy addresses; 127.0.0.1 is always included.";
    };

    enableIPv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable IPv6 in jellyfin.";
    };

    declarativelyManageNetwork = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Always overwrite network.xml on service start; set false to only write when absent.";
    };
  };

  module = {
    init =
      config:
      lib.mkIf config.nx.common.dev.claude.enable {
        nx.common.dev.claude.allowedWebFetchDomains = [ "jellyfin\\.org" ];
      };

    enabled = config: {
      nx.packages.extra = [ pkgs.jellyfin ];
    };

    linux.system =
      {
        config,
        subdomain,
        port,
        httpsPort,
        dataDir,
        extraConfig,
        extraMediaPath,
        enableRemoteAccess,
        localNetworkSubnets,
        knownProxies,
        enableIPv6,
        declarativelyManageNetwork,
      }:
      let
        boolStr = b: if b then "true" else "false";
        mkXmlStrings = items: lib.concatMapStrings (s: "    <string>${s}</string>\n") items;
        allProxies = [ "127.0.0.1" ] ++ knownProxies;
        networkXml = pkgs.writeText "jellyfin-network.xml" ''
          <?xml version="1.0" encoding="utf-8"?>
          <!-- Managed declaratively via Nix; do not edit manually -->
          <NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
            <BaseUrl />
            <EnableHttps>false</EnableHttps>
            <RequireHttps>false</RequireHttps>
            <InternalHttpPort>${toString port}</InternalHttpPort>
            <InternalHttpsPort>${toString httpsPort}</InternalHttpsPort>
            <PublicHttpPort>${toString port}</PublicHttpPort>
            <PublicHttpsPort>${toString httpsPort}</PublicHttpsPort>
            <AutoDiscovery>true</AutoDiscovery>
            <EnableIPv4>true</EnableIPv4>
            <EnableIPv6>${boolStr enableIPv6}</EnableIPv6>
            <EnableRemoteAccess>${boolStr enableRemoteAccess}</EnableRemoteAccess>
            <LocalNetworkSubnets>
          ${mkXmlStrings localNetworkSubnets}  </LocalNetworkSubnets>
            <LocalNetworkAddresses />
            <KnownProxies>
          ${mkXmlStrings allProxies}  </KnownProxies>
            <IgnoreVirtualInterfaces>true</IgnoreVirtualInterfaces>
            <VirtualInterfaceNames>
              <string>veth</string>
            </VirtualInterfaceNames>
            <EnablePublishedServerUriByRequest>false</EnablePublishedServerUriByRequest>
            <PublishedServerUriBySubnet />
            <RemoteIPFilter />
            <IsRemoteIPFilterBlacklist>false</IsRemoteIPFilterBlacklist>
          </NetworkConfiguration>
        '';
      in
      {
        users.groups.jellyfin-sync = { };
        users.users.jellyfin.extraGroups = [ "jellyfin-sync" ];

        services.jellyfin = extraConfig // {
          enable = true;
          group = "jellyfin-sync";
          openFirewall = false;
          dataDir = dataDir;
        };

        systemd.services.jellyfin.preStart =
          lib.optionalString (!declarativelyManageNetwork) ''
            if [ -f "${dataDir}/config/network.xml" ]; then
              exit 0
            fi
          ''
          + ''
            ${pkgs.coreutils}/bin/install -d -m 750 "${dataDir}/config"
            ${pkgs.coreutils}/bin/install -m 640 ${networkXml} "${dataDir}/config/network.xml"
          '';

        systemd.tmpfiles.settings."jellyfinDirs" = {
          "${dataDir}".d = lib.mkOverride 90 {
            mode = "0750";
            user = "jellyfin";
            group = "jellyfin-sync";
          };
          "${dataDir}/media".d = lib.mkOverride 90 {
            mode = "0750";
            user = "jellyfin";
            group = "jellyfin-sync";
          };
        }
        // lib.optionalAttrs (extraMediaPath != null) {
          "${extraMediaPath}".d = {
            mode = "0750";
            user = "jellyfin";
            group = "jellyfin-sync";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${dataDir}".d = lib.mkOverride 90 {
            mode = "0750";
            user = "jellyfin";
            group = "jellyfin-sync";
          };
          "${self.persist}${dataDir}/media".d = lib.mkOverride 90 {
            mode = "0750";
            user = "jellyfin";
            group = "jellyfin-sync";
          };
          "${self.persist}/var/cache/jellyfin".d = lib.mkOverride 90 {
            mode = "0750";
            user = "jellyfin";
            group = "jellyfin-sync";
          };
        };

        environment.persistence = lib.mkIf self.host.impermanence {
          "${self.persist}".directories = [
            {
              directory = dataDir;
              user = "jellyfin";
              group = "jellyfin-sync";
              mode = "0750";
            }
            {
              directory = "/var/cache/jellyfin";
              user = "jellyfin";
              group = "jellyfin-sync";
              mode = "0750";
            }
          ];
        };
      };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.skipPaths = [
          config.nx.linux.server.jellyfin.dataDir
        ]
        ++ lib.optional (
          config.nx.linux.server.jellyfin.extraMediaPath != null
        ) config.nx.linux.server.jellyfin.extraMediaPath;
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
          exposedService = self.host.remote.exposedServices.jellyfin;
          isExposed = exposedService != false;
          exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;
        in
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
                message = "linux.server.jellyfin requires linux.security.letsencrypt to be enabled!";
              }
              {
                assertion = domain != null;
                message = "linux.server.jellyfin requires host.remote.baseDomain to be set!";
              }
              {
                assertion = exposedService == false || exposedSubdomain == subdomain;
                message = "linux.server.jellyfin: subdomain '${subdomain}' does not match exposedServices.jellyfin subdomain '${exposedSubdomain}'!";
              }
            ];
          }
          (lib.mkIf (domain != null) {
            services.nginx.virtualHosts."${subdomain}.${domain}" = {
              useACMEHost = domain;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                recommendedProxySettings = false;
                extraConfig = ''
                  proxy_http_version 1.1;
                  proxy_buffering off;
                  client_max_body_size 20M;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_set_header X-Forwarded-Host $host;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "upgrade";
                '';
              };
              locations."/socket" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                recommendedProxySettings = false;
                extraConfig = ''
                  proxy_http_version 1.1;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "upgrade";
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                '';
              };
            };
          })
        ];
    };

    ifEnabled.linux.notifications.pushover = {
      linux.system =
        {
          config,
          dataDir,
          subdomain,
          extraMediaPath,
        }:
        let
          domain = self.host.remote.baseDomain;
          pushover = config.nx.linux.notifications.pushover;
          extraMediaNote =
            lib.optionalString (extraMediaPath != null)
              " USB drive media path: ${extraMediaPath}. Mount exFAT with: mount -o uid=$(id -u jellyfin),gid=$(id -g jellyfin-sync),umask=027 /dev/DEVICE ${extraMediaPath}. Then add it as a library in the UI. Add a fileSystems entry in nxconfig for a persistent mount.";
        in
        lib.mkIf (domain != null && pushover.send != null) {
          systemd.services.jellyfin-setup-notify = {
            description = "Notify about jellyfin first-start admin setup";
            before = [ "jellyfin.service" ];
            wantedBy = [ "jellyfin.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = toString (
                pkgs.writeShellScript "jellyfin-setup-notify" ''
                  if [ ! -f "${dataDir}/config/system.xml" ]; then
                    ${pushover.send {
                      title = "Jellyfin";
                      message = "First start: visit https://${subdomain}.${domain} to create admin account. Add media library at: ${dataDir}/media.${extraMediaNote}";
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
        nx.linux.server.healthchecks.requireServicesUp = [ "jellyfin.service" ];
        nx.linux.server.healthchecks.loadHighCpuExemptProcessCmdlines = [ "jellyfin-ffmpeg" ];
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.jellyfin;
          subdomain = config.nx.linux.server.jellyfin.subdomain;
        in
        lib.mkIf (domain != null && exposedService != false) {
          nx.linux.server.dashboard.services = [
            {
              name = "Jellyfin";
              href = "https://${subdomain}.${domain}";
              description = "Media server";
              icon = "jellyfin";
              group = "services";
            }
          ];
        };
    };
  };
}
