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
  name = "pushover";

  group = "notifications";
  input = "linux";

  options = {
    defaultPriority = lib.mkOption {
      type = lib.types.int;
      default = 0;
    };
    pushoverAPIEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "https://api.pushover.net/1/messages.json";
    };
    defaultSound = lib.mkOption {
      type = lib.types.str;
      default = "none";
    };
    defaultTtl = lib.mkOption {
      type = lib.types.str;
      default = "";
    };
    priorityDefaults = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            sound = lib.mkOption {
              type = lib.types.str;
              default = "none";
            };
            ttl = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
          };
        }
      );
      default = {
        "-2" = {
          sound = "none";
          ttl = "14400";
        };
        "-1" = {
          sound = "none";
          ttl = "28800";
        };
        "0" = {
          sound = "vibrate";
          ttl = "259200";
        };
        "1" = {
          sound = "pushover";
          ttl = "1209600";
        };
        "2" = {
          sound = "tugboat";
          ttl = "";
        };
      };
    };
    typeDefaults = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            sound = lib.mkOption {
              type = lib.types.str;
              default = "none";
            };
            ttl = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
          };
        }
      );
      default = {
        started = {
          sound = "vibrate";
          ttl = "14400";
        };
        stopped = {
          sound = "pushover";
          ttl = "1209600";
        };
        failed = {
          sound = "pushover";
          ttl = "1209600";
        };
        warn = {
          sound = "gamelan";
          ttl = "1209600";
        };
        success = {
          sound = "pianobar";
          ttl = "259200";
        };
        info = {
          sound = "vibrate";
          ttl = "86400";
        };
        debug = {
          sound = "none";
          ttl = "7200";
        };
        emerg = {
          sound = "tugboat";
          ttl = "";
        };
      };
    };

    script = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The pushover-send script derivation (set in system namespace, null in home)";
    };

    sendList = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo (lib.types.listOf lib.types.str));
      default = null;
      description = "Function to generate a pushover-send command as a list of arguments";
    };

    send = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function to generate a pushover-send shell command string";
    };

    sendAsPythonList = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function to generate a Python list string with f-strings for variable interpolation";
    };
  };

  module =
    let
      generateBashArray =
        name: attrset: field:
        let
          entries = lib.mapAttrsToList (
            key: value:
            let
              fieldValue = if value ? ${field} then value.${field} else "";
            in
            "[\"${key}\"]=\"${fieldValue}\""
          ) attrset;
        in
        "declare -A ${name}=(${lib.concatStringsSep " " entries})";

      pushoverSendScript =
        config:
        pkgs.writeShellScriptBin "pushover-send" ''
          set -euo pipefail

          ${generateBashArray "PRIORITY_SOUND" (self.options config).priorityDefaults "sound"}
          ${generateBashArray "PRIORITY_TTL" (self.options config).priorityDefaults "ttl"}
          ${generateBashArray "TYPE_SOUND" (self.options config).typeDefaults "sound"}
          ${generateBashArray "TYPE_TTL" (self.options config).typeDefaults "ttl"}

          DEFAULT_SOUND="${(self.options config).defaultSound}"
          DEFAULT_TTL="${(self.options config).defaultTtl}"

          show_usage() {
              echo "Usage: $0 --title <title> --message <message> [--priority <priority>] [--type <type>] [--url <url>] [--url-title <url-title>] [--html] [--debug] [--dry-run] [-h|--help] [-- <extra-pushover-args>]" >&2
              echo "Types: started, stopped, failed, warn, success, info, debug, emerg" >&2
          }

          TITLE=""
          MESSAGE=""
          PRIORITY="${toString (self.options config).defaultPriority}"
          PRIORITY_SET=false
          TYPE=""
          URL=""
          URL_TITLE=""
          HTML_MODE=false
          DEBUG_MODE=false
          DRY_RUN=false
          EXTRA_ARGS=()

          while [[ $# -gt 0 ]]; do
              case $1 in
                  -h|--help)
                      show_usage
                      exit 0
                      ;;
                  --title)
                      TITLE="$2"
                      shift 2
                      ;;
                  --message)
                      MESSAGE="$2"
                      shift 2
                      ;;
                  --priority)
                      PRIORITY="$2"
                      PRIORITY_SET=true
                      shift 2
                      ;;
                  --type)
                      TYPE="$2"
                      shift 2
                      ;;
                  --url)
                      URL="$2"
                      shift 2
                      ;;
                  --url-title)
                      URL_TITLE="$2"
                      shift 2
                      ;;
                  --html)
                      HTML_MODE=true
                      shift
                      ;;
                  --debug)
                      DEBUG_MODE=true
                      shift
                      ;;
                  --dry-run)
                      DRY_RUN=true
                      DEBUG_MODE=true
                      shift
                      ;;
                  --)
                      shift
                      EXTRA_ARGS=("$@")
                      break
                      ;;
                  *)
                      echo "Unknown option: $1" >&2
                      show_usage
                      exit 1
                      ;;
              esac
          done

          if [[ -z "$TITLE" || -z "$MESSAGE" ]]; then
              echo "Error: --title and --message are required" >&2
              show_usage
              exit 1
          fi

          if [[ -n "$URL_TITLE" && -z "$URL" ]]; then
              echo "Error: --url-title can only be used when --url is also specified" >&2
              exit 1
          fi

          if [[ -n "$TYPE" && "$PRIORITY_SET" == "false" ]]; then
              case "$TYPE" in
                  started) PRIORITY="-2" ;;
                  stopped) PRIORITY="0" ;;
                  failed) PRIORITY="1" ;;
                  warn) PRIORITY="1" ;;
                  success) PRIORITY="0" ;;
                  info) PRIORITY="0" ;;
                  debug) PRIORITY="-2" ;;
                  emerg) PRIORITY="2" ;;
                  *)
                      echo "Error: Invalid type '$TYPE'" >&2
                      echo "Valid types: started, stopped, failed, warn, success, info, debug, emerg" >&2
                      exit 1
                      ;;
              esac
          fi

          FORMATTED_TITLE="$TITLE"
          if [[ -n "$TYPE" ]]; then
              case "$TYPE" in
                  started) EMOTICON="🚀" ;;
                  stopped) EMOTICON="🟥" ;;
                  failed) EMOTICON="❌" ;;
                  warn) EMOTICON="⚠️" ;;
                  success) EMOTICON="✅" ;;
                  info) EMOTICON="💡" ;;
                  debug) EMOTICON="🐞" ;;
                  emerg) EMOTICON="❗" ;;
              esac

              FORMATTED_TITLE="$EMOTICON $TITLE ($TYPE)"
          fi

          if [[ "$PRIORITY_SET" == "true" ]]; then
              SOUND="''${PRIORITY_SOUND[$PRIORITY]:-$DEFAULT_SOUND}"
              TTL="''${PRIORITY_TTL[$PRIORITY]:-$DEFAULT_TTL}"
          elif [[ -n "$TYPE" ]]; then
              SOUND="''${TYPE_SOUND[$TYPE]:-$DEFAULT_SOUND}"
              TTL="''${TYPE_TTL[$TYPE]:-$DEFAULT_TTL}"
          else
              SOUND="$DEFAULT_SOUND"
              TTL="$DEFAULT_TTL"
          fi

          if [[ $EUID -eq 0 ]]; then
              TOKEN_FILE="/run/secrets/${self.host.hostname}-pushover-token"
              USER_FILE="/run/secrets/pushover-user"
          else
              TOKEN_FILE="/run/pushover-token-${self.host.mainUser.username}"
              USER_FILE="/run/pushover-user-${self.host.mainUser.username}"

              if [[ ! -r "$TOKEN_FILE" || ! -r "$USER_FILE" ]]; then
                  echo "Error: Pushover secrets not accessible for user. Run as root or ensure secrets are properly configured." >&2
                  exit 1
              fi
          fi

          TEMP_DIR=$(${pkgs.coreutils}/bin/mktemp -d)
          TEMP_CONFIG="$TEMP_DIR/curl-config"

          trap "${pkgs.coreutils}/bin/rm -rf '$TEMP_DIR'" EXIT

          ${pkgs.coreutils}/bin/touch "$TEMP_CONFIG"
          ${pkgs.coreutils}/bin/chmod 600 "$TEMP_CONFIG"

          escape_for_curl() {
              printf '%s' "$1" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g; s/"/\\"/g'
          }

          escape_message_for_curl() {
              local text="$1"
              if [[ "$HTML_MODE" == "true" ]]; then
                  text=$(printf '%s' "$text" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g; s/"/\\"/g')
              else
                  text=$(printf '%s' "$text" | ${pkgs.gnused}/bin/sed 's/\\/\\\\/g; s/"/\\"/g; s/</⟨/g; s/>/⟩/g')
              fi
              local output=""
              local line
              while IFS= read -r line || [[ -n "$line" ]]; do
                  if [[ -n "$output" ]]; then
                      output="$output<br/>$line"
                  else
                      output="$line"
                  fi
              done <<< "$text"
              text="$output"
              printf '%s' "$text"
          }

          ESCAPED_TITLE=$(escape_for_curl "$FORMATTED_TITLE [${self.host.hostname}]")

          ESCAPED_MESSAGE=$(escape_message_for_curl "$MESSAGE")

          cat > "$TEMP_CONFIG" <<EOF
          form = "token=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")"
          form = "user=$(${pkgs.coreutils}/bin/cat "$USER_FILE")"
          form = "title=$ESCAPED_TITLE"
          form = "message=$ESCAPED_MESSAGE"
          form = "priority=$PRIORITY"
          form = "html=1"
          form = "timestamp=$(${pkgs.coreutils}/bin/date +%s)"
          form = "sound=$SOUND"
          EOF

          if [[ -n "$TTL" && "$PRIORITY" != "2" ]]; then
              echo "form = \"ttl=$TTL\"" >> "$TEMP_CONFIG"
          fi

          if [[ "$PRIORITY" == "2" ]]; then
              echo "form = \"retry=900\"" >> "$TEMP_CONFIG"
              echo "form = \"expire=10800\"" >> "$TEMP_CONFIG"
          fi

          if [[ -n "$URL" ]]; then
              ESCAPED_URL=$(escape_for_curl "$URL")
              echo "form = \"url=$ESCAPED_URL\"" >> "$TEMP_CONFIG"

              if [[ -n "$URL_TITLE" ]]; then
                  ESCAPED_URL_TITLE=$(escape_for_curl "$URL_TITLE")
                  echo "form = \"url_title=$ESCAPED_URL_TITLE\"" >> "$TEMP_CONFIG"
              fi
          fi

          for arg in "''${EXTRA_ARGS[@]}"; do
              ESCAPED_ARG=$(escape_for_curl "$arg")
              echo "form = \"$ESCAPED_ARG\"" >> "$TEMP_CONFIG"
          done

          if [[ "$DRY_RUN" == "true" ]]; then
              echo "=== DRY RUN MODE ===" >&2
          fi

          if [[ "$DEBUG_MODE" == "true" ]]; then
              echo "=== DEBUG: Curl config file content ===" >&2
              ${pkgs.coreutils}/bin/cat "$TEMP_CONFIG" >&2
              echo "=== END DEBUG ===" >&2
          fi

          if [[ "$DRY_RUN" == "true" ]]; then
              exit 0
          fi

          for attempt in {1..5}; do
              if ${pkgs.curl}/bin/curl -fsS -m 30 --connect-timeout 10 -o /dev/null --config "$TEMP_CONFIG" ${(self.options config).pushoverAPIEndpoint}; then
                  exit 0
              else
                  exit_code=$?
                  if [[ $attempt -lt 5 ]]; then
                      sleep_time=$((attempt * 2))
                      echo "Pushover API call failed (attempt $attempt/5), retrying in $sleep_time seconds..." >&2
                      ${pkgs.coreutils}/bin/sleep $sleep_time
                  else
                      echo "Pushover API call failed after 5 attempts" >&2
                      ${
                        self.notifyUser {
                          inherit pkgs;
                          title = "Pushover Notification Failed";
                          body = "Pushover API call failed after 5 attempts. Please check your internet connection and try again!\\n\\n<b>Title</b>: <u>$TITLE</u>\\n<b>Message</b>: <u>$MESSAGE</u>";
                          icon = "dialog-error";
                          urgency = "critical";
                          validation = { inherit config; };
                        }
                      } || true
                      exit $exit_code
                  fi
              fi
          done
        '';
    in
    {
      linux.init =
        config:
        let
          sendListFn =
            {
              title,
              message,
              type ? null,
              priority ? null,
              url ? null,
              urlTitle ? null,
              html ? false,
              path ? null,
              extraArgs ? [ ],
              shellVars ? false,
            }:
            let
              script = config.nx.linux.notifications.pushover.script;
              scriptCmd =
                if !self.isEnabled then
                  null
                else if path != null then
                  path
                else if script != null then
                  "${script}/bin/pushover-send"
                else
                  "pushover-send";
            in
            if scriptCmd == null then
              [ ]
            else
              [
                scriptCmd
                "--title"
                title
                "--message"
                message
              ]
              ++ lib.optionals (type != null) [
                "--type"
                type
              ]
              ++ lib.optionals (priority != null) [
                "--priority"
                (toString priority)
              ]
              ++ lib.optionals (url != null) [
                "--url"
                url
              ]
              ++ lib.optionals (urlTitle != null) [
                "--url-title"
                urlTitle
              ]
              ++ lib.optionals html [ "--html" ]
              ++ extraArgs;
        in
        {
          nx.linux.notifications.pushover.sendList = sendListFn;

          nx.linux.notifications.pushover.send =
            args:
            let
              cmdList = sendListFn args;
              shellVars = args.shellVars or false;
              escapeDoubleQuotes = s: builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s;
              doubleQuote = s: "\"${escapeDoubleQuotes s}\"";
              buildDoubleQuotedCmd = lib.concatStringsSep " " (
                [
                  (builtins.head cmdList)
                  "--title"
                  (doubleQuote args.title)
                  "--message"
                  (doubleQuote args.message)
                ]
                ++ lib.optionals (args.type or null != null) [
                  "--type"
                  (doubleQuote args.type)
                ]
                ++ lib.optionals (args.priority or null != null) [
                  "--priority"
                  (toString args.priority)
                ]
                ++ lib.optionals (args.url or null != null) [
                  "--url"
                  (doubleQuote args.url)
                ]
                ++ lib.optionals (args.urlTitle or null != null) [
                  "--url-title"
                  (doubleQuote args.urlTitle)
                ]
                ++ lib.optionals (args.html or false) [ "--html" ]
                ++ (args.extraArgs or [ ])
              );
            in
            if cmdList == [ ] then
              ":"
            else if shellVars then
              "${buildDoubleQuotedCmd} || true"
            else
              "${lib.escapeShellArgs cmdList} || true";

          nx.linux.notifications.pushover.sendAsPythonList =
            args:
            let
              cmdList = sendListFn args;
              toPyFStr = s: "f\"${s}\"";
            in
            if cmdList == [ ] then "[]" else "[${lib.concatStringsSep ", " (map toPyFStr cmdList)}]";
        };

      linux.enabled = config: {
        nx.linux.notifications.pushover.script = pushoverSendScript config;
      };

      linux.system =
        config:
        let
          hostname = self.host.hostname;
          mainUser = config.users.users.${self.host.mainUser.username};
          mainUserGroup = mainUser.group;
        in
        {
          sops.secrets."pushover-user" = {
            format = "binary";
            sopsFile = self.config.secretsPath "pushover-user";
            mode = if (self.isModuleEnabled "security.letsencrypt") then "0440" else "0400";
            owner = "root";
            group = if (self.isModuleEnabled "security.letsencrypt") then "acme" else "root";
          };

          sops.secrets."${hostname}-pushover-token" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "pushover-token";
            mode = if (self.isModuleEnabled "security.letsencrypt") then "0440" else "0400";
            owner = "root";
            group = if (self.isModuleEnabled "security.letsencrypt") then "acme" else "root";
          };

          sops.secrets."pushover-user-${self.host.mainUser.username}" = {
            format = "binary";
            sopsFile = self.config.secretsPath "pushover-user";
            mode = "0440";
            owner = "root";
            group = mainUserGroup;
            path = "/run/pushover-user-${self.host.mainUser.username}";
          };

          sops.secrets."pushover-token-${self.host.mainUser.username}" = {
            format = "binary";
            sopsFile = self.profile.secretsPath "pushover-token";
            mode = "0440";
            owner = "root";
            group = mainUserGroup;
            path = "/run/pushover-token-${self.host.mainUser.username}";
          };

          environment.systemPackages = [
            config.nx.linux.notifications.pushover.script
            pkgs.curl
          ];
        };
    };
}
