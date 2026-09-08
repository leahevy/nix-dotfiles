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
  name = "immich";
  description = "Self-hosted photo and video backup and gallery";

  group = "server";
  input = "linux";

  submodules = {
    linux.server = [
      "postgresql"
      "redis"
    ];
  };

  options = {
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "photos";
      description = "Subdomain for the nginx vhost.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "Port immich listens on.";
    };

    mediaLocation = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nx-immich-data";
      description = "Directory for immich media files.";
    };

    externalLibraryPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/nx-immich-library";
      description = "Directory for the syncthing-managed external library, added as an External Library in the Immich web UI.";
    };

    libraryScanIntervalHours = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "How often to scan external libraries, in hours.";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra settings merged into services.immich.settings.";
    };

    galleries = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable immich-kiosk gallery vhosts. Requires a binary SOPS secret at immich-kiosk-api-key in the host profile secrets directory.";
          };

          kioskPort = lib.mkOption {
            type = lib.types.port;
            default = 3100;
            description = "Port immich-kiosk listens on.";
          };

          kioskSettings = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Extra settings merged on top of the hardcoded kiosk defaults in services.immich-kiosk.settings.";
          };

          restrictToInternalNetwork = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Restrict gallery vhosts to internal network IPs via the nginx nx_is_internal geo variable.";
          };

          albums = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = lib.mkOption {
                    type = lib.types.str;
                    description = "Album name used in the subdomain slug and as a label.";
                  };
                  albumId = lib.mkOption {
                    type = lib.types.str;
                    description = "Immich album UUID.";
                  };
                };
              }
            );
            default = [ ];
            description = "Albums to expose as internal-only gallery vhosts via immich-kiosk.";
          };
        };
      };
      default = { };
      description = "Immich-kiosk photo frame gallery configuration.";
    };
  };

  module = {
    init =
      config:
      lib.mkIf config.nx.common.dev.claude.enable {
        nx.common.dev.claude.allowedWebFetchDomains = [
          "immich\\.app"
          "docs\\.immich\\.app"
        ];
      };

    enabled = config: {
      nx.packages.extra = [ pkgs.immich ];
      nx.linux.server.postgresql.connectionSlots = [ 60 ];
    };

    linux.system =
      {
        config,
        subdomain,
        port,
        mediaLocation,
        externalLibraryPath,
        libraryScanIntervalHours,
        extraSettings,
        galleries,
      }:
      let
        domain = self.host.remote.baseDomain;
        exposedService = self.host.remote.exposedServices.immich;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;
        sharedKioskSettings = {
          disable_ui = true;
          duration = 30;
          transition = "fade";
          image_fit = "cover";
          show_time = true;
          show_date = true;
          background_blur = true;
        }
        // galleries.kioskSettings;
        kioskHardening = {
          DynamicUser = true;
          Restart = "on-failure";
          RestartSec = 10;
          RuntimeDirectoryMode = "0700";
          Type = "simple";
          CapabilityBoundingSet = [ "" ];
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          PrivateUsers = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
            "~@resources"
          ];
        };
        mkAlbumKioskService =
          {
            name,
            albumId,
            port,
          }:
          let
            staticConfig = (pkgs.formats.json { }).generate "immich-kiosk-${name}.json" (
              sharedKioskSettings
              // {
                immich_url = "https://${subdomain}.${domain}";
                kiosk.port = port;
                albums = [ albumId ];
              }
            );
          in
          {
            description = "Immich Kiosk - ${name}";
            after = [
              "network.target"
              "immich-server.service"
            ];
            wantedBy = [ "multi-user.target" ];
            preStart = ''
              ${pkgs.jq}/bin/jq \
                --rawfile key "$CREDENTIALS_DIRECTORY/immich-kiosk-api-key" \
                '. + {immich_api_key: ($key | rtrimstr("\n"))}' \
                ${staticConfig} \
                > /run/immich-kiosk-${name}/config.yaml
              ${pkgs.coreutils}/bin/chmod 600 /run/immich-kiosk-${name}/config.yaml
            '';
            serviceConfig = kioskHardening // {
              RuntimeDirectory = "immich-kiosk-${name}";
              WorkingDirectory = "/run/immich-kiosk-${name}";
              ExecStart = lib.getExe pkgs.immich-kiosk;
              SyslogIdentifier = "immich-kiosk-${name}";
              LoadCredential = [ "immich-kiosk-api-key:${config.sops.secrets."immich-kiosk-api-key".path}" ];
            };
          };
      in
      {
        assertions = [
          {
            assertion = domain != null;
            message = "linux.server.immich requires host.remote.baseDomain to be set!";
          }
          {
            assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.immich requires linux.security.letsencrypt to be enabled!";
          }
          {
            assertion = exposedService == false || exposedSubdomain == subdomain;
            message = "linux.server.immich: subdomain '${subdomain}' does not match exposedServices.immich '${exposedSubdomain}'!";
          }
          {
            assertion = !galleries.enable || galleries.albums != [ ];
            message = "linux.server.immich: galleries.enable is true but galleries.albums is empty!";
          }
        ];

        users.groups.immich-sync = { };

        services.immich = {
          enable = true;
          host = "127.0.0.1";
          group = "immich-sync";
          mediaLocation = mediaLocation;
          port = port;
          settings = lib.recursiveUpdate {
            server = lib.optionalAttrs (domain != null) {
              externalDomain = "https://${subdomain}.${domain}";
            };
            library.scan = {
              enabled = true;
              cronExpression = "*/${toString libraryScanIntervalHours} * * * *";
            };
          } extraSettings;
        };

        systemd.tmpfiles.settings."immichDirs" = {
          "${mediaLocation}".d = lib.mkOverride 90 {
            mode = "0700";
            user = "immich";
            group = "immich-sync";
          };
          "${externalLibraryPath}".d = lib.mkOverride 90 {
            mode = "0750";
            user = "immich";
            group = "immich-sync";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}/var/lib/immich".d = lib.mkOverride 90 {
            mode = "0700";
            user = "immich";
            group = "immich-sync";
          };
          "${self.persist}${mediaLocation}".d = lib.mkOverride 90 {
            mode = "0700";
            user = "immich";
            group = "immich-sync";
          };
          "${self.persist}${externalLibraryPath}".d = lib.mkOverride 90 {
            mode = "0750";
            user = "immich";
            group = "immich-sync";
          };
        };

        environment.persistence."${self.persist}".directories = [
          "/var/lib/immich"
          mediaLocation
          externalLibraryPath
        ];

        sops.secrets = lib.optionalAttrs galleries.enable {
          "immich-kiosk-api-key" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "immich-kiosk-api-key";
            mode = "0400";
          };
        };

        services.immich-kiosk = lib.mkIf galleries.enable {
          enable = true;
          settings = {
            immich_api_key._secret = config.sops.secrets."immich-kiosk-api-key".path;
            kiosk.port = galleries.kioskPort;
            albums = map (a: a.albumId) galleries.albums;
          }
          // sharedKioskSettings;
        };

        systemd.services = lib.optionalAttrs (galleries.enable && galleries.albums != [ ]) (
          lib.listToAttrs (
            lib.imap0 (
              index: album:
              lib.nameValuePair "immich-kiosk-${album.name}" (mkAlbumKioskService {
                name = album.name;
                albumId = album.albumId;
                port = galleries.kioskPort + 1 + index;
              })
            ) galleries.albums
          )
        );
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          subdomain,
          port,
          galleries,
        }:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.immich;
        in
        lib.mkIf (domain != null && exposedService != false) {
          services.nginx.virtualHosts = {
            "${subdomain}.${domain}" = {
              useACMEHost = domain;
              forceSSL = true;
              locations."/" = {
                proxyPass = "http://127.0.0.1:${toString port}";
                recommendedProxySettings = false;
                extraConfig = ''
                  proxy_http_version 1.1;
                  proxy_redirect off;
                  proxy_buffering off;
                  proxy_request_buffering off;
                  client_max_body_size 50000M;
                  client_body_buffer_size 1024k;
                  proxy_read_timeout 600s;
                  proxy_send_timeout 600s;
                  send_timeout 600s;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
                  proxy_set_header Upgrade $http_upgrade;
                  proxy_set_header Connection "upgrade";
                '';
              };
            };
          }
          // lib.optionalAttrs (galleries.enable && galleries.albums != [ ]) (
            lib.listToAttrs (
              lib.imap0 (
                index: album:
                lib.nameValuePair "${subdomain}-gallery-${album.name}.${domain}" {
                  useACMEHost = domain;
                  forceSSL = true;
                  locations."/" = {
                    proxyPass = "http://127.0.0.1:${toString (galleries.kioskPort + 1 + index)}";
                    recommendedProxySettings = false;
                    extraConfig = ''
                      ${lib.optionalString galleries.restrictToInternalNetwork "if ($nx_is_internal = 0) { return 403; }"}
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                    '';
                  };
                }
              ) galleries.albums
            )
            // {
              "${subdomain}-gallery.${domain}" = {
                useACMEHost = domain;
                forceSSL = true;
                locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString galleries.kioskPort}";
                  recommendedProxySettings = false;
                  extraConfig = ''
                    ${lib.optionalString galleries.restrictToInternalNetwork "if ($nx_is_internal = 0) { return 403; }"}
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  '';
                };
              };
            }
          );
        };
    };

    ifEnabled.linux.notifications.pushover = {
      linux.system =
        {
          config,
          mediaLocation,
          externalLibraryPath,
          subdomain,
        }:
        let
          domain = self.host.remote.baseDomain;
          pushover = config.nx.linux.notifications.pushover;
        in
        lib.mkIf (domain != null && pushover.send != null) {
          systemd.services.immich-setup-notify = {
            description = "Notify about immich first-start admin setup";
            before = [ "immich-server.service" ];
            wantedBy = [ "immich-server.service" ];
            partOf = [ "immich-server.service" ];
            serviceConfig = {
              Type = "oneshot";
              ExecStart = toString (
                pkgs.writeShellScript "immich-setup-notify" ''
                  if [ ! -f "${mediaLocation}/.nx-setup-notified" ]; then
                    ${pushover.send {
                      title = "Immich";
                      message = "First start: visit https://${subdomain}.${domain} to create admin account. Add external library at: ${externalLibraryPath}.";
                    }}
                    ${pkgs.coreutils}/bin/touch "${mediaLocation}/.nx-setup-notified"
                  fi
                ''
              );
            };
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [
          "immich-server.service"
          "immich-machine-learning.service"
        ]
        ++ lib.optionals config.nx.linux.server.immich.galleries.enable (
          [ "immich-kiosk.service" ]
          ++ map (album: "immich-kiosk-${album.name}.service") config.nx.linux.server.immich.galleries.albums
        );
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.immich;
          subdomain = config.nx.linux.server.immich.subdomain;
        in
        lib.mkIf (domain != null && exposedService != false) {
          nx.linux.server.dashboard.services = [
            {
              name = "Immich";
              href = "https://${subdomain}.${domain}";
              description = "Photo library";
              icon = "immich";
              group = "services";
            }
          ];
        };
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.skipPaths = [
          config.nx.linux.server.immich.mediaLocation
          config.nx.linux.server.immich.externalLibraryPath
        ];
      };
    };
  };
}
