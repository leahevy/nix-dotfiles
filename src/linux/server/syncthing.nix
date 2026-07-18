args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  mkSyncthingQueryApi =
    {
      config,
      guiPort,
    }:
    pkgs.writeShellScriptBin "syncthing-query-api" ''
      set -euo pipefail

      if [[ "$EUID" -ne 0 ]]; then
        echo "Must be run as root!"
        exit 1
      fi

      if [[ "$#" -lt 1 ]]; then
        echo "Usage: syncthing-query-api API_PATH [curl args...]"
        echo "Example: syncthing-query-api /rest/db/status?folder=myfolder"
        exit 1
      fi

      API_PATH="$1"
      shift
      CONFIG_XML=${lib.escapeShellArg "${config.services.syncthing.configDir}/config.xml"}

      if [[ ! -r "$CONFIG_XML" ]]; then
        echo "Syncthing config.xml is not readable!"
        exit 1
      fi

      API_KEY=$(${pkgs.libxml2}/bin/xmllint --xpath 'string(configuration/gui/apikey)' "$CONFIG_XML" 2>/dev/null || true)
      if [[ -z "$API_KEY" ]]; then
        echo "Could not read the Syncthing API key!"
        exit 1
      fi

      HEADER_FILE=$(${pkgs.coreutils}/bin/mktemp)
      trap '${pkgs.coreutils}/bin/rm -f "$HEADER_FILE"' EXIT
      ${pkgs.coreutils}/bin/chmod 600 "$HEADER_FILE"
      printf 'X-API-Key: %s\n' "$API_KEY" > "$HEADER_FILE"

      case "$API_PATH" in
        /*) ;;
        *)
          echo "API_PATH must start with /"
          exit 1
          ;;
      esac

      ${pkgs.curl}/bin/curl -sS -H @"$HEADER_FILE" \
        "$@" \
        "http://127.0.0.1:${toString guiPort}$API_PATH"
    '';
in
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

    paperlessFolderDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Named Syncthing devices to declaratively assign to the Paperless import and export folders.";
    };

    enablePullErrorsHealthCheck = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable a standalone health check that fails when Syncthing folders report pull errors.";
    };

    pullErrorsHealthCheckInterval = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      description = "Interval for the standalone Syncthing pull error health check.";
    };

    pullErrorsHealthCheckUUID = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Healthchecks.io UUID of the Syncthing pull errors health check.";
    };
  };

  module = {
    enabled = config: {
      nx.packages.extra = [ pkgs.syncthing ];
    };

    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        let
          queryApiExe = lib.getExe (mkSyncthingQueryApi {
            inherit config;
            guiPort = config.nx.linux.server.syncthing.guiPort;
          });
        in
        {
          nx.linux.server.healthchecks.requireServicesUp = [ "syncthing.service" ];
          nx.linux.server.healthchecks.loadHighCpuExemptCommands = [ "syncthing" ];
          nx.linux.server.healthchecks.timedHealthChecks =
            lib.mkIf config.nx.linux.server.syncthing.enablePullErrorsHealthCheck
              {
                "syncthing" = {
                  interval = config.nx.linux.server.syncthing.pullErrorsHealthCheckInterval;
                  uuid = config.nx.linux.server.syncthing.pullErrorsHealthCheckUUID;
                  icon = "syncthing";
                  checks = {
                    "10 - Syncthing API reachable" = ''
                      FOLDERS_JSON=$(${queryApiExe} /rest/config/folders --connect-timeout 5 --max-time 10 2>&1) || {
                        printf '%s\n' "$FOLDERS_JSON" >&3
                        exit 1
                      }
                      if [[ -z "$FOLDERS_JSON" ]]; then
                        printf 'Could not fetch folders from the Syncthing API!\n' >&3
                        exit 1
                      fi

                      FOLDER_COUNT=$(printf '%s' "$FOLDERS_JSON" | ${pkgs.jq}/bin/jq -r 'length' 2>/dev/null || true)
                      if [[ -z "$FOLDER_COUNT" ]]; then
                        printf 'Syncthing folders response was not valid JSON!\n' >&3
                        exit 1
                      fi

                      printf 'folders: %s\n' "$FOLDER_COUNT" >&3
                    '';
                    "20 - Syncthing pull errors" = ''
                      format_folder_status() {
                        local folder="$1"
                        local status="$2"
                        local width=30
                        local len=''${#folder}
                        local dots
                        if [[ "$len" -ge "$width" ]]; then
                          dots="..."
                        else
                          dots=$(printf '%*s' "$((width - len))" "")
                          dots=''${dots// /.}
                        fi
                        printf '%s%s %s\n' "$folder" "$dots" "$status" >&3
                      }

                      FOLDERS=$(${queryApiExe} /rest/config/folders --connect-timeout 5 --max-time 10 \
                        | ${pkgs.jq}/bin/jq -r '.[].id' 2>/dev/null || true)

                      if [[ -z "$FOLDERS" ]]; then
                        printf 'No Syncthing folders configured.\n' >&3
                        exit 0
                      fi

                      FAILED=0
                      while IFS= read -r FOLDER; do
                        [[ -n "$FOLDER" ]] || continue
                        ERRORS=
                        LAST_REASON=
                        ATTEMPT=1
                        while [[ "$ATTEMPT" -le 3 ]]; do
                          RESPONSE=$(${queryApiExe} "/rest/db/status?folder=$FOLDER" --connect-timeout 5 --max-time 10 2>/dev/null || true)
                          if [[ -z "$RESPONSE" ]]; then
                            LAST_REASON="empty response"
                          else
                            ERRORS=$(printf '%s' "$RESPONSE" | ${pkgs.jq}/bin/jq -er '.pullErrors' 2>/dev/null || true)
                            case "$ERRORS" in
                              ""|*[!0-9]*)
                                LAST_REASON="invalid pullErrors data"
                                ERRORS=
                                ;;
                              *)
                                LAST_REASON=
                                break
                                ;;
                            esac
                          fi
                          if [[ "$ATTEMPT" -lt 3 ]]; then
                            printf '%s: %s, retrying in %ss\n' "$FOLDER" "$LAST_REASON" "$ATTEMPT" >&2
                            ${pkgs.coreutils}/bin/sleep "$ATTEMPT"
                          fi
                          ATTEMPT=$((ATTEMPT + 1))
                        done
                        if [[ -n "$LAST_REASON" ]]; then
                          format_folder_status "$FOLDER" "$LAST_REASON"
                          FAILED=1
                          continue
                        fi
                        format_folder_status "$FOLDER" "$ERRORS pull errors"
                        if [[ "$ERRORS" -gt 0 ]]; then
                          FAILED=1
                        fi
                      done <<EOF
                      $FOLDERS
                      EOF

                      if [[ "$FAILED" -ne 0 ]]; then
                        exit 1
                      fi
                    '';
                  };
                };
              };
        };
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.skipPaths = [ config.nx.linux.server.syncthing.dataDir ];
      };
    };

    ifEnabled.linux.server.dashboard = {
      enabled =
        config:
        let
          domain = self.host.remote.baseDomain;
          exposedService = self.host.remote.exposedServices.syncthing;
          subdomain = config.nx.linux.server.syncthing.subdomain;
        in
        lib.mkIf (domain != null && exposedService != false) {
          nx.linux.server.dashboard.services = [
            {
              name = "Syncthing";
              href = "https://${subdomain}.${domain}";
              description = "File synchronization across devices";
              icon = "syncthing";
              group = "admin";
            }
          ];
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
        queryApiPackage = mkSyncthingQueryApi { inherit config guiPort; };
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

        environment.systemPackages = [
          queryApiPackage
        ];

        environment.persistence."${self.persist}" = {
          directories = [ dataDir ];
        };

        systemd.tmpfiles.settings."nx-syncthing" = {
          "${dataDir}".d = {
            mode = "0700";
            user = "syncthing";
            group = "syncthing";
          };
        }
        // lib.optionalAttrs self.host.impermanence {
          "${self.persist}${dataDir}".d = {
            mode = "0700";
            user = "syncthing";
            group = "syncthing";
          };
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

        systemd.services.syncthing.restartTriggers = [
          (builtins.toJSON config.users.users.syncthing.extraGroups)
        ];

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
                if ($nx_is_internal = 0) { return 403; }
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
          folderDevices =
            if config.nx.linux.server.syncthing.paperlessFolderDevices == [ ] then
              lib.attrNames config.services.syncthing.settings.devices
            else
              config.nx.linux.server.syncthing.paperlessFolderDevices;
        in
        {
          users.groups.paperless-sync = { };
          users.users.syncthing.extraGroups = [ "paperless-sync" ];
          users.users.paperless.extraGroups = [ "paperless-sync" ];

          systemd.tmpfiles.settings."10-paperless" = {
            "${basePath}".d = lib.mkOverride 75 {
              mode = "0750";
              user = "paperless";
              group = "paperless-sync";
            };
            "${basePath}/import".d = lib.mkOverride 75 {
              mode = "2770";
              user = "paperless";
              group = "paperless-sync";
            };
          }
          // lib.optionalAttrs self.host.impermanence {
            "${self.persist}${basePath}".d = lib.mkOverride 75 {
              mode = "0750";
              user = "paperless";
              group = "paperless-sync";
            };
            "${self.persist}${basePath}/import".d = lib.mkOverride 75 {
              mode = "2770";
              user = "paperless";
              group = "paperless-sync";
            };
          };
          systemd.tmpfiles.settings."10-paperless-export" = {
            "${basePath}/export".d = lib.mkOverride 75 {
              mode = "2770";
              user = "paperless";
              group = "paperless-sync";
            };
          }
          // lib.optionalAttrs self.host.impermanence {
            "${self.persist}${basePath}/export".d = lib.mkOverride 75 {
              mode = "2770";
              user = "paperless";
              group = "paperless-sync";
            };
          };

          services.syncthing.settings.folders = {
            "paperless-import" = {
              path = "${basePath}/import";
              label = "Paperless Import";
              devices = folderDevices;
            };
            "paperless-export" = {
              path = "${basePath}/export";
              label = "Paperless Export";
              devices = folderDevices;
            };
          };

          systemd.services.syncthing.restartTriggers = [
            (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless" or { }))
            (builtins.toJSON (config.systemd.tmpfiles.settings."10-paperless-export" or { }))
          ];
        };
    };
  };
}
