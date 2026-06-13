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
  name = "samba";
  group = "server";
  input = "linux";
  description = "Samba SMB file server backed by the LDAP user directory";

  submodules = {
    linux.server.ldap = true;
  };

  options = {
    workgroup = lib.mkOption {
      type = lib.types.str;
      default = "WORKGROUP";
      description = "NetBIOS workgroup name advertised by the Samba server.";
    };

    serverString = lib.mkOption {
      type = lib.types.str;
      default = "Samba File Server";
      description = "Human-readable server description shown to SMB clients.";
    };

    shares = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Share name and subdirectory name under /var/lib/samba-shared.";
            };
            validUsers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "@ldap-users" ];
              description = "SMB users or groups allowed to access this share, prefix group names with @.";
            };
          };
        }
      );
      default = [ ];
      description = "Additional named shares created as subdirectories under /var/lib/samba-shared.";
    };

    additionalAllowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional CIDR ranges appended to the built-in RFC1918 hosts allow list.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the standard Samba ports in the host firewall.";
    };
  };

  module = {
    ifEnabled.linux.server.ldap = {
      linux.system =
        {
          config,
          workgroup,
          serverString,
          shares,
          additionalAllowedHosts,
          openFirewall,
          ...
        }:
        let
          users = config.nx.linux.server.ldap.users;
          homeBase = config.nx.linux.server.ldap.homeBase;
          usernames = map (u: u.username) users;
          shareNames = map (share: share.name) shares;
          allowedHosts = lib.concatStringsSep " " (
            [
              "127.0.0.1"
              "::1"
              "192.168.0.0/16"
              "10.0.0.0/8"
              "172.16.0.0/12"
              "fe80::/10"
              "fc00::/7"
            ]
            ++ additionalAllowedHosts
          );
          setupScript = pkgs.writeShellScript "nx-samba-password-setup" ''
            set -euo pipefail
            _retries=0
            until [ -f /var/lib/samba/private/secrets.tdb ] || [ $_retries -ge 30 ]; do
              sleep 1
              _retries=$((_retries + 1))
            done
            if [ ! -f /var/lib/samba/private/secrets.tdb ]; then
              printf 'samba private directory not initialized after 30s\n' >&2
              exit 1
            fi
            ${lib.concatMapStrings (u: ''
              _pass=$(${pkgs.coreutils}/bin/cat ${
                lib.escapeShellArg config.sops.secrets."samba-pass-${u.username}".path
              })
              if ${pkgs.samba}/bin/pdbedit -L 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q "^${u.username}:"; then
                printf '%s\n%s\n' "$_pass" "$_pass" | ${pkgs.samba}/bin/smbpasswd -s ${lib.escapeShellArg u.username}
              else
                printf '%s\n%s\n' "$_pass" "$_pass" | ${pkgs.samba}/bin/smbpasswd -a -s ${lib.escapeShellArg u.username}
              fi
            '') users}
          '';
        in
        {
          assertions = [
            {
              assertion = users != [ ];
              message = "linux.server.samba: linux.server.ldap has no users declared, add at least one user!";
            }
            {
              assertion = builtins.length (lib.unique shareNames) == builtins.length shareNames;
              message = "linux.server.samba: duplicate share names in shares list!";
            }
          ]
          ++ map (share: {
            assertion = builtins.match "^[a-z0-9_-]+$" share.name != null;
            message = "linux.server.samba: share name '${share.name}' must match ^[a-z0-9_-]+$!";
          }) shares
          ++ map (share: {
            assertion = !builtins.elem share.name usernames;
            message = "linux.server.samba: share name '${share.name}' conflicts with an LDAP username and would collide with the generated home share!";
          }) shares;

          sops.secrets = lib.listToAttrs (
            map (
              u:
              lib.nameValuePair "samba-pass-${u.username}" {
                format = "binary";
                sopsFile = self.profile.secretsPath "samba-pass-${u.username}";
                mode = "0400";
                owner = "root";
                group = "root";
              }
            ) users
          );

          systemd.services.nx-samba-password-setup = {
            description = "Samba password initialization";
            after = [ "samba-smbd.service" ];
            requires = [ "samba-smbd.service" ];
            wantedBy = [ "samba-smbd.service" ];
            bindsTo = [ "samba-smbd.service" ];
            restartTriggers = map (u: config.sops.secrets."samba-pass-${u.username}".sopsFile) users;
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              PrivateTmp = true;
              ProtectSystem = "strict";
              ReadOnlyPaths = [ "/run/secrets" ];
              ReadWritePaths = [ "/var/lib/samba" ];
              ExecStart = toString setupScript;
            };
          };

          services.samba = {
            enable = true;
            openFirewall = openFirewall;
            winbindd.enable = false;
            settings = {
              global = {
                workgroup = workgroup;
                "server string" = serverString;
                security = "user";
                "passdb backend" = "tdbsam";
                "server min protocol" = "SMB3";
                "server smb encrypt" = "if_required";
                "hosts allow" = allowedHosts;
                "hosts deny" = "ALL";
                "map to guest" = "Never";
                "log level" = "1";
              };
            }
            // lib.listToAttrs (
              map (
                u:
                lib.nameValuePair u.username {
                  path = "${homeBase}/${u.username}";
                  browseable = "yes";
                  "read only" = "no";
                  "valid users" = u.username;
                  "create mask" = "0600";
                  "directory mask" = "0700";
                  "force user" = u.username;
                  "force group" = u.username;
                  "server smb encrypt" = "required";
                }
              ) users
            )
            // lib.listToAttrs (
              map (
                share:
                lib.nameValuePair share.name {
                  path = "/var/lib/samba-shared/${share.name}";
                  browseable = "yes";
                  "read only" = "no";
                  "valid users" = lib.concatStringsSep " " share.validUsers;
                  "create mask" = "0664";
                  "directory mask" = "0775";
                  "force group" = "ldap-users";
                  "server smb encrypt" = "required";
                }
              ) shares
            );
          };

          systemd.tmpfiles.settings."nx-samba" = {
            "/var/lib/samba".d = {
              mode = "0755";
              user = "root";
              group = "root";
            };
            "/var/lib/samba-shared".d = {
              mode = "0770";
              user = "root";
              group = "ldap-users";
            };
          }
          // lib.optionalAttrs (!self.host.impermanence) {
            "/var/lib/samba/private".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
          }
          // lib.listToAttrs (
            lib.concatMap (
              share:
              let
                entry = {
                  mode = "0770";
                  user = "root";
                  group = "ldap-users";
                };
              in
              [
                {
                  name = "/var/lib/samba-shared/${share.name}";
                  value."d" = entry;
                }
              ]
              ++ lib.optional self.host.impermanence {
                name = "${self.persist}/var/lib/samba-shared/${share.name}";
                value."d" = entry;
              }
            ) shares
          )
          // lib.optionalAttrs self.host.impermanence {
            "${self.persist}/var/lib/samba".d = {
              mode = "0755";
              user = "root";
              group = "root";
            };
            "${self.persist}/var/lib/samba/private".d = {
              mode = "0700";
              user = "root";
              group = "root";
            };
            "${self.persist}/var/lib/samba-shared".d = {
              mode = "0770";
              user = "root";
              group = "ldap-users";
            };
          };

          environment.persistence."${self.persist}" = {
            directories = [
              "/var/lib/samba"
              "/var/lib/samba-shared"
            ];
          };
        };
    };

    ifEnabled.linux.networking.tailscale = {
      enabled = config: {
        nx.linux.server.samba.additionalAllowedHosts = [ "100.64.0.0/10" ];
      };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [
          "samba-smbd.service"
          "samba-nmbd.service"
        ];
      };
    };

    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "smbd";
          string = ".*smbXsrv_session_disconnect_xconn: empty session_table, nothing to do\\..*";
          all = true;
        }
      ];
    };

  };
}
