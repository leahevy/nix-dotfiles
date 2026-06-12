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
  mkPocketIdQueryApi =
    { port }:
    pkgs.writeShellScriptBin "pocket-id-query-api" ''
      set -euo pipefail

      if [[ "$EUID" -ne 0 ]]; then
        printf 'Must be run as root!\n' >&2
        exit 1
      fi

      if [[ "$#" -lt 2 ]]; then
        printf 'Usage: pocket-id-query-api METHOD API_PATH [curl args...]\n' >&2
        printf 'Example: pocket-id-query-api GET /api/oidc/clients\n' >&2
        exit 1
      fi

      METHOD="$1"
      API_PATH="$2"
      shift 2

      case "$API_PATH" in
        /*) ;;
        *)
          printf 'API_PATH must start with /\n' >&2
          exit 1
          ;;
      esac

      ENV_FILE="/run/pocket-id-env/env"
      if [[ ! -r "$ENV_FILE" ]]; then
        printf 'Pocket-ID env file not readable: %s\n' "$ENV_FILE" >&2
        exit 1
      fi

      API_KEY=$(${pkgs.gnugrep}/bin/grep '^POCKET_ID_API_KEY=' "$ENV_FILE" | ${pkgs.coreutils}/bin/cut -d= -f2- || true)
      if [[ ! "$API_KEY" =~ ^[a-zA-Z0-9]{32}$ ]]; then
        printf 'Pocket-ID API key not configured or invalid\n' >&2
        exit 1
      fi

      WORK_DIR=$(${pkgs.coreutils}/bin/mktemp -d -p /run/pocket-id)
      trap '${pkgs.coreutils}/bin/rm -rf "$WORK_DIR"' EXIT
      ${pkgs.coreutils}/bin/chmod 700 "$WORK_DIR"

      HEADER_FILE="$WORK_DIR/headers"
      printf 'X-API-KEY: %s\n' "$API_KEY" > "$HEADER_FILE"
      ${pkgs.coreutils}/bin/chmod 600 "$HEADER_FILE"

      ${pkgs.curl}/bin/curl -sSf -X "$METHOD" -H @"$HEADER_FILE" \
        "$@" \
        "http://127.0.0.1:${toString port}$API_PATH"
    '';
in
{
  name = "pocket-id";
  group = "server";
  input = "linux";
  description = "Pocket-ID OIDC authentication provider";

  options = {
    port = lib.mkOption {
      type = lib.types.int;
      default = 1411;
      description = "Local port the Pocket-ID server listens on.";
    };

    envVarFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variable names mapped to secret file paths whose contents are appended to the Pocket-ID environment file by the prepare service.";
    };

    bootstrapMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow graceful skip when the API key is not yet configured; when false the env-prepare and ensure-apps services fail hard if the key is absent or malformed.";
    };
  };

  module = {
    enabled =
      config:
      let
        domain = self.host.remote.baseDomain;
        subdomain = config.nx.linux.server.auth.subdomain;
      in
      {
        nx.linux.server.auth.baseUrl = lib.mkIf (domain != null) "https://${subdomain}.${domain}";
        nx.linux.server.auth.oidcDiscoveryUrl = lib.mkIf (
          domain != null
        ) "https://${subdomain}.${domain}/.well-known/openid-configuration";
        nx.linux.server.auth.oidcProviderName = lib.mkIf (domain != null) "Pocket-ID";
        nx.linux.server.auth.oidcProviderId = lib.mkIf (domain != null) "pocket-id";
        nx.linux.server.auth.logoutUrl = lib.mkIf (domain != null) (
          let
            base = "https://${subdomain}.${domain}/oidc/session/end";
            redirect = config.nx.linux.server.auth.postLogoutRedirectUrl;
          in
          if redirect != null then "${base}?post_logout_redirect_uri=${redirect}" else base
        );
      };

    linux.system =
      {
        config,
        port,
        envVarFiles,
        bootstrapMode,
        ...
      }:
      let
        clients = config.nx.linux.server.auth.clients;
        domain = self.host.remote.baseDomain;
        subdomain = config.nx.linux.server.auth.subdomain;
        baseUrl = "https://${subdomain}.${domain}";
        exposedService = self.host.remote.exposedServices.auth;
        isExposed = exposedService != false;
        exposedSubdomain = if builtins.isString exposedService then exposedService else subdomain;

        accentColor = config.nx.preferences.theme.colors.blocks.primary.foreground.html;

        secretKeyPath = config.sops.secrets."pocket-id-secret-key".path;
        apiKeyPath = if bootstrapMode then "" else config.sops.secrets."pocket-id-api-key".path;

        postLogoutRedirectUrl = config.nx.linux.server.auth.postLogoutRedirectUrl;

        declaredJson = builtins.toJSON (
          lib.mapAttrs (_k: c: {
            inherit (c)
              name
              callbackUrls
              allowedUserGroup
              ;
          }) clients
        );

        ensureAppsScript = pkgs.writeShellScript "nx-pocket-id-ensure-apps" ''
          set -euo pipefail

          LOCAL_URL="http://127.0.0.1:${toString port}"
          JQ="${pkgs.jq}/bin/jq"
          CURL="${pkgs.curl}/bin/curl"
          DECLARED=${lib.escapeShellArg declaredJson}

          API_KEY="''${POCKET_ID_API_KEY:-}"
          if [[ ! "$API_KEY" =~ ^[a-zA-Z0-9]{32}$ ]]; then
            printf "POCKET_ID_API_KEY absent or not a valid 32-char alphanumeric key${
              if bootstrapMode then
                ", skipping client sync"
              else
                ", failing (set bootstrapMode = true during initial setup)"
            }\n" >&2
            exit ${if bootstrapMode then "0" else "1"}
          fi

          WORK_DIR=$(${pkgs.coreutils}/bin/mktemp -d -p /run/pocket-id)
          trap '${pkgs.coreutils}/bin/rm -rf "$WORK_DIR"' EXIT
          ${pkgs.coreutils}/bin/chmod 700 "$WORK_DIR"

          HEADER_FILE="$WORK_DIR/headers"
          printf 'X-API-KEY: %s\n' "$API_KEY" > "$HEADER_FILE"
          ${pkgs.coreutils}/bin/chmod 600 "$HEADER_FILE"

          api() {
            local method="$1" path="$2"
            shift 2
            "$CURL" -sSf -X "$method" \
              -H @"$HEADER_FILE" \
              -H "Content-Type: application/json" \
              "$@" "$LOCAL_URL$path"
          }

          CURRENT=$(api GET /api/oidc/clients) || {
            printf 'Failed to reach Pocket-ID API\n' >&2
            exit 1
          }

          DECLARED_NAMES=$("$JQ" '[to_entries[].value.name]' <<< "$DECLARED")
          while IFS=$'\t' read -r CID CNAME; do
            [[ -n "$CID" ]] || continue
            IN_DECL=$("$JQ" -r --arg n "$CNAME" 'map(. == $n) | any' <<< "$DECLARED_NAMES")
            if [[ "$IN_DECL" != "true" ]]; then
              printf 'Removing client no longer declared: %s\n' "$CNAME"
              api DELETE "/api/oidc/clients/$CID" >/dev/null
            fi
          done < <("$JQ" -r '.[] | [.id, .name] | @tsv' <<< "$CURRENT")

          while IFS= read -r KEY; do
            [[ -n "$KEY" ]] || continue
            CLIENT_NAME=$("$JQ" -r --arg k "$KEY" '.[$k].name' <<< "$DECLARED")
            CALLBACK_URLS=$("$JQ" -c --arg k "$KEY" '.[$k].callbackUrls' <<< "$DECLARED")
            ALLOWED_GROUP=$("$JQ" -r --arg k "$KEY" '.[$k].allowedUserGroup // empty' <<< "$DECLARED")
            LOGOUT_CALLBACK_URLS=${
              lib.escapeShellArg (
                builtins.toJSON (if postLogoutRedirectUrl != null then [ postLogoutRedirectUrl ] else [ ])
              )
            }

            EXISTING_ID=$("$JQ" -r --arg n "$CLIENT_NAME" '.[] | select(.name == $n) | .id' <<< "$CURRENT")

            GROUP_ID=""
            if [[ -n "$ALLOWED_GROUP" ]]; then
              GROUPS=$(api GET /api/user-groups) || true
              GROUP_ID=$("$JQ" -r --arg n "$ALLOWED_GROUP" '.data[]? | select(.name == $n) | .id' <<< "$GROUPS")
              if [[ -z "$GROUP_ID" ]]; then
                printf 'Group %s not found in Pocket-ID, skipping group restriction for %s\n' "$ALLOWED_GROUP" "$CLIENT_NAME" >&2
              fi
            fi

            if [[ -z "$EXISTING_ID" ]]; then
              printf 'Skipping client %s: not found in pocket-id, create it manually in the UI first\n' "$CLIENT_NAME" >&2
              continue
            fi

            PAYLOAD_FILE="$WORK_DIR/payload_$KEY"
            if [[ -n "$GROUP_ID" ]]; then
              "$JQ" -n \
                --arg name "$CLIENT_NAME" \
                --argjson urls "$CALLBACK_URLS" \
                --argjson logoutUrls "$LOGOUT_CALLBACK_URLS" \
                --arg gid "$GROUP_ID" \
                '{name: $name, callbackURLs: $urls, logoutCallbackURLs: $logoutUrls, isPublic: false, pkceEnabled: true, allowedUserGroups: [{id: $gid}]}' > "$PAYLOAD_FILE"
            else
              "$JQ" -n \
                --arg name "$CLIENT_NAME" \
                --argjson urls "$CALLBACK_URLS" \
                --argjson logoutUrls "$LOGOUT_CALLBACK_URLS" \
                '{name: $name, callbackURLs: $urls, logoutCallbackURLs: $logoutUrls, isPublic: false, pkceEnabled: true}' > "$PAYLOAD_FILE"
            fi
            ${pkgs.coreutils}/bin/chmod 600 "$PAYLOAD_FILE"

            printf 'Updating client: %s\n' "$CLIENT_NAME"
            api PUT "/api/oidc/clients/$EXISTING_ID" -d @"$PAYLOAD_FILE" >/dev/null
          done < <("$JQ" -r 'keys[]' <<< "$DECLARED")

          printf 'Pocket-ID client sync complete\n'
        '';
      in
      {
        assertions = [
          {
            assertion = isExposed;
            message = "linux.server.pocket-id requires host.remote.exposedServices.auth to be set: Pocket ID requires HTTPS for WebAuthn to function!";
          }
          {
            assertion = !isExposed || config.nx.linux.security.letsencrypt.enable;
            message = "linux.server.pocket-id requires linux.security.letsencrypt to be enabled when exposed!";
          }
          {
            assertion = domain != null;
            message = "linux.server.pocket-id requires host.remote.baseDomain to be set!";
          }
          {
            assertion = !isExposed || exposedSubdomain == subdomain;
            message = "linux.server.pocket-id: subdomain '${subdomain}' does not match exposedServices.auth subdomain '${exposedSubdomain}'!";
          }
        ];

        sops.secrets = {
          "pocket-id-secret-key" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "pocket-id-secret-key";
            owner = "root";
            mode = "0400";
          };
        }
        // lib.optionalAttrs (!bootstrapMode) {
          "pocket-id-api-key" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "pocket-id-api-key";
            owner = "root";
            mode = "0400";
          };
        };

        environment.systemPackages = lib.optional (!bootstrapMode) (mkPocketIdQueryApi {
          inherit port;
        });

        systemd.services.nx-pocket-id-env = {
          description = "Prepare Pocket-ID environment file";
          before = [ "pocket-id.service" ];
          wantedBy = [ "pocket-id.service" ];
          partOf = [ "pocket-id.service" ];
          restartTriggers = [
            config.sops.secrets."pocket-id-secret-key".sopsFile
          ]
          ++ lib.optional (!bootstrapMode) config.sops.secrets."pocket-id-api-key".sopsFile;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            RuntimeDirectory = "pocket-id-env";
            RuntimeDirectoryMode = "0700";
            ExecStart = toString (
              pkgs.writeShellScript "nx-pocket-id-prepare-env" ''
                umask 077
                ${pkgs.coreutils}/bin/rm -f /run/pocket-id-env/env
                ${pkgs.coreutils}/bin/touch /run/pocket-id-env/env
                {
                  printf 'SECRET_KEY='
                  ${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg secretKeyPath}
                  printf '\n'
                } >> /run/pocket-id-env/env
                ${lib.optionalString (!bootstrapMode) ''
                  {
                    printf 'POCKET_ID_API_KEY='
                    ${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg apiKeyPath}
                    printf '\n'
                  } >> /run/pocket-id-env/env
                ''}
                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (varName: filePath: ''
                    {
                      printf '${varName}='
                      ${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg filePath}
                      printf '\n'
                    } >> /run/pocket-id-env/env
                  '') envVarFiles
                )}
                ${lib.optionalString (!bootstrapMode) ''
                  _pid_api_key=$(${pkgs.coreutils}/bin/tr -d '\n' < ${lib.escapeShellArg apiKeyPath})
                  if [[ ! "$_pid_api_key" =~ ^[a-zA-Z0-9]{32}$ ]]; then
                    printf 'CRITICAL: pocket-id-api-key does not contain a valid 32-char alphanumeric key!\n' >&2
                    printf 'Set nx.linux.server.pocket-id.bootstrapMode = true to skip during initial setup.\n' >&2
                    exit 1
                  fi
                ''}
              ''
            );
          };
        };

        services.pocket-id = {
          enable = true;
          environmentFile = "/run/pocket-id-env/env";
          settings = {
            APP_URL = baseUrl;
            TRUST_PROXY = true;
            ANALYTICS_DISABLED = true;
            UI_CONFIG_DISABLED = true;
            ALLOW_USER_SIGNUPS = "disabled";
            ALLOW_OWN_ACCOUNT_EDIT = false;
            ACCENT_COLOR = accentColor;
          };
        };

        systemd.services.pocket-id = {
          after = [ "nx-pocket-id-env.service" ];
          requires = [ "nx-pocket-id-env.service" ];
          restartTriggers = [
            config.sops.secrets."pocket-id-secret-key".sopsFile
          ]
          ++ lib.optional (!bootstrapMode) config.sops.secrets."pocket-id-api-key".sopsFile;
        };

        environment.persistence."${self.persist}" = {
          directories = [ "/var/lib/pocket-id" ];
        };

        systemd.tmpfiles.settings."pocket-id-run" = {
          "/run/pocket-id".d = {
            mode = "0700";
            user = "root";
            group = "root";
          };
        };

        systemd.tmpfiles.settings."pocket-id-state" = {
          "/var/lib/pocket-id".d = {
            mode = "0700";
            user = "pocket-id";
            group = "pocket-id";
          };
        };

        systemd.services.nx-pocket-id-ensure-apps = {
          description = "Pocket-ID OIDC client sync";
          after = [
            "nx-pocket-id-env.service"
            "pocket-id.service"
          ];
          requires = [
            "nx-pocket-id-env.service"
            "pocket-id.service"
          ];
          partOf = [ "pocket-id.service" ];
          wantedBy = [ "pocket-id.service" ];
          restartTriggers = [ (builtins.toJSON clients) ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = "/run/pocket-id-env/env";
            ExecStart = "${ensureAppsScript}";
          };
        };
      };

    ifEnabled.linux.server.nginx = {
      linux.system =
        {
          config,
          port,
          ...
        }:
        let
          domain = self.host.remote.baseDomain;
          subdomain = config.nx.linux.server.auth.subdomain;
          exposedService = self.host.remote.exposedServices.auth;
        in
        lib.mkIf (exposedService != false) {
          services.nginx.virtualHosts."${subdomain}.${domain}" = {
            useACMEHost = domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              proxyWebsockets = true;
              recommendedProxySettings = false;
              extraConfig = ''
                proxy_set_header Host $host;
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

    ifEnabled.linux.server.ldap = {
      enabled = config: {
        nx.linux.server.pocket-id.envVarFiles.LDAP_BIND_PASSWORD =
          config.nx.linux.server.ldap.readerPasswordFile;
      };

      linux.system =
        config:
        let
          ldap = config.nx.linux.server.ldap;
        in
        {
          systemd.services.pocket-id = {
            after = [ "openldap.service" ];
            bindsTo = [ "openldap.service" ];
            restartTriggers = [ config.sops.secrets."openldap-reader-pass".sopsFile ];
          };

          systemd.services.nx-pocket-id-env.restartTriggers = [
            config.sops.secrets."openldap-reader-pass".sopsFile
          ];

          services.pocket-id.settings = {
            LDAP_ENABLED = true;
            LDAP_SOFT_DELETE_USERS = false;
            LDAP_URL = ldap.ldapUrl;
            LDAP_BASE = ldap.baseDn;
            LDAP_BIND_DN = ldap.readerDn;
            LDAP_SKIP_CERT_VERIFY = true;
            LDAP_USER_SEARCH_FILTER = "(objectClass=posixAccount)";
            LDAP_USER_GROUP_SEARCH_FILTER = ldap.groupSearchFilter;
            LDAP_ATTRIBUTE_USER_UNIQUE_IDENTIFIER = "uid";
            LDAP_ATTRIBUTE_USER_USERNAME = "uid";
            LDAP_ATTRIBUTE_USER_EMAIL = "mail";
            LDAP_ATTRIBUTE_USER_FIRST_NAME = "givenName";
            LDAP_ATTRIBUTE_USER_LAST_NAME = "sn";
            LDAP_ATTRIBUTE_GROUP_UNIQUE_IDENTIFIER = "cn";
            LDAP_ATTRIBUTE_GROUP_NAME = "cn";
            LDAP_ATTRIBUTE_GROUP_MEMBER = ldap.groupMemberAttribute;
          };
        };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled =
        config:
        let
          queryApiExe = lib.getExe (mkPocketIdQueryApi {
            port = config.nx.linux.server.pocket-id.port;
          });
        in
        {
          nx.linux.server.healthchecks.requireServicesUp = [
            "pocket-id.service"
            "nx-pocket-id-ensure-apps.service"
            "nx-pocket-id-env.service"
          ];
          nx.linux.server.healthchecks.regularHealthChecks = {
            "R+50 - Pocket-ID API" = ''
              _pid_api_key=$(${pkgs.gnugrep}/bin/grep '^POCKET_ID_API_KEY=' /run/pocket-id-env/env 2>/dev/null | ${pkgs.coreutils}/bin/cut -d= -f2- || true)
              if [[ ! "$_pid_api_key" =~ ^[a-zA-Z0-9]{32}$ ]]; then
                printf 'Pocket-ID API key not configured, skipping API check\n' >&3
                exit 0
              fi
              _pid_resp=$(${queryApiExe} GET /api/oidc/clients --connect-timeout 5 --max-time 10 2>&1) || {
                printf 'Pocket-ID API unreachable: %s\n' "$_pid_resp" >&3
                exit 1
              }
              _pid_count=$(printf '%s' "$_pid_resp" | ${pkgs.jq}/bin/jq 'length' 2>/dev/null || echo "?")
              printf 'clients: %s\n' "$_pid_count" >&3
            '';
          };
        };
    };

  };
}
