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

    mailScript = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "The sendmail-compatible pushover-mail script derivation (set in system namespace, null in home)";
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

    mkMailWrapper = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.str);
      default = null;
      description = "Function to generate a sendmail-compatible wrapper with baked-in Pushover defaults";
    };

    enableSendmail = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install pushover-mail as the system sendmail at /run/wrappers/bin/sendmail.";
    };

    enableE2EEncryption = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Encrypt messages end-to-end using AES-256-CBC with a 64-char hex key stored in the pushover-e2e-key config SOPS secret.";
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
        let
          enableE2E = config.nx.linux.notifications.pushover.enableE2EEncryption;
        in
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

          ${lib.optionalString enableE2E ''
            if [[ $EUID -eq 0 ]]; then
                E2E_KEY_FILE="/run/secrets/pushover-e2e-key"
            else
                E2E_KEY_FILE="/run/pushover-e2e-key-${self.host.mainUser.username}"
                if [[ ! -r "$E2E_KEY_FILE" ]]; then
                    echo "Error: Pushover e2e key not accessible for user." >&2
                    exit 1
                fi
            fi

            E2E_KEY=$(${pkgs.coreutils}/bin/tr -d '[:space:]' < "$E2E_KEY_FILE")
            if [[ ! "$E2E_KEY" =~ ^[0-9A-Fa-f]{64}$ ]]; then
                echo "Error: Pushover e2e key must be exactly 64 hexadecimal characters." >&2
                exit 1
            fi

          ''}TEMP_DIR=$(${pkgs.coreutils}/bin/mktemp -d)
          TEMP_CONFIG="$TEMP_DIR/curl-config"

          trap "${pkgs.coreutils}/bin/rm -rf '$TEMP_DIR'" EXIT

          ${pkgs.coreutils}/bin/touch "$TEMP_CONFIG"
          ${pkgs.coreutils}/bin/chmod 600 "$TEMP_CONFIG"

          ${lib.optionalString enableE2E ''
            encrypt_field() {
                printf '%s' "$1" | ${
                  pkgs.writers.writePython3Bin "pushover-encrypt"
                    {
                      libraries = [ pkgs.python3Packages.cryptography ];
                    }
                    ''
                      import sys
                      import gzip
                      import os
                      import hmac
                      import hashlib
                      import base64

                      from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
                      from cryptography.hazmat.primitives import padding

                      key_hex = open(sys.argv[1]).read().strip()
                      key = bytes.fromhex(key_hex)
                      plaintext = sys.stdin.buffer.read()

                      compressed = gzip.compress(plaintext, compresslevel=9)
                      iv = os.urandom(16)

                      cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
                      encryptor = cipher.encryptor()
                      padder = padding.PKCS7(128).padder()
                      padded = padder.update(compressed) + padder.finalize()
                      ct = encryptor.update(padded) + encryptor.finalize()

                      mac = hmac.digest(key, iv + ct, hashlib.sha256)
                      sys.stdout.write(base64.b64encode(iv + ct + mac).decode())
                    ''
                }/bin/pushover-encrypt "$E2E_KEY_FILE"
            }

          ''}escape_for_curl() {
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
          TEMP_MESSAGE="$TEMP_DIR/message-content"
          printf '%s' "$ESCAPED_MESSAGE" > "$TEMP_MESSAGE"

          ${lib.optionalString enableE2E ''
            ENC_TITLE=$(encrypt_field "$FORMATTED_TITLE [${self.host.hostname}]")
            ENC_MESSAGE=$(encrypt_field "$(${pkgs.coreutils}/bin/cat "$TEMP_MESSAGE")")

          ''}cat > "$TEMP_CONFIG" <<EOF
          form = "token=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")"
          form = "user=$(${pkgs.coreutils}/bin/cat "$USER_FILE")"
          ${if enableE2E then "form = \"title=$ENC_TITLE\"" else "form = \"title=$ESCAPED_TITLE\""}
          ${if enableE2E then "form = \"message=$ENC_MESSAGE\"" else "form = \"message=<$TEMP_MESSAGE\""}
          form = "priority=$PRIORITY"
          form = "html=1"
          form = "timestamp=$(${pkgs.coreutils}/bin/date +%s)"
          form = "sound=$SOUND"
          ${lib.optionalString enableE2E ''
            form = "encrypted=1"
          ''}EOF

          if [[ -n "$TTL" && "$PRIORITY" != "2" ]]; then
              echo "form = \"ttl=$TTL\"" >> "$TEMP_CONFIG"
          fi

          if [[ "$PRIORITY" == "2" ]]; then
              echo "form = \"retry=900\"" >> "$TEMP_CONFIG"
              echo "form = \"expire=10800\"" >> "$TEMP_CONFIG"
          fi

          ${
            if enableE2E then
              ''
                if [[ -n "$URL" ]]; then
                    ENC_URL=$(encrypt_field "$URL")
                    echo "form = \"url=$ENC_URL\"" >> "$TEMP_CONFIG"

                    if [[ -n "$URL_TITLE" ]]; then
                        ENC_URL_TITLE=$(encrypt_field "$URL_TITLE")
                        echo "form = \"url_title=$ENC_URL_TITLE\"" >> "$TEMP_CONFIG"
                    fi
                fi
              ''
            else
              ''
                if [[ -n "$URL" ]]; then
                    ESCAPED_URL=$(escape_for_curl "$URL")
                    echo "form = \"url=$ESCAPED_URL\"" >> "$TEMP_CONFIG"

                    if [[ -n "$URL_TITLE" ]]; then
                        ESCAPED_URL_TITLE=$(escape_for_curl "$URL_TITLE")
                        echo "form = \"url_title=$ESCAPED_URL_TITLE\"" >> "$TEMP_CONFIG"
                    fi
                fi
              ''
          }
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

      pushoverMailScript =
        config: pushoverSendPackage:
        pkgs.writeShellScriptBin "pushover-mail" ''
          set -euo pipefail

          show_usage() {
              echo "Usage: $0 [--pushover-json <json>] [-t] [-f sender] [-r sender] [-i|-oi] [recipient ...]" >&2
          }

          PUSHOVER_JSON="{}"
          EXTRACT_RECIPIENTS=false
          IGNORE_DOT=false
          ENVELOPE_FROM=""
          RECIPIENTS=()

          while [[ $# -gt 0 ]]; do
              case $1 in
                  --help|-h)
                      show_usage
                      exit 0
                      ;;
                  --pushover-json)
                      if [[ $# -lt 2 ]]; then
                          echo "pushover-mail: --pushover-json requires an argument" >&2
                          exit 1
                      fi
                      PUSHOVER_JSON="$2"
                      shift 2
                      ;;
                  -t)
                      EXTRACT_RECIPIENTS=true
                      shift
                      ;;
                  -f|-r)
                      if [[ $# -lt 2 ]]; then
                          echo "pushover-mail: $1 requires an argument" >&2
                          exit 1
                      fi
                      ENVELOPE_FROM="$2"
                      shift 2
                      ;;
                  -i|-oi)
                      IGNORE_DOT=true
                      shift
                      ;;
                  --)
                      shift
                      while [[ $# -gt 0 ]]; do
                          RECIPIENTS+=("$1")
                          shift
                      done
                      ;;
                  -*)
                      echo "pushover-mail: ignoring unsupported sendmail option: $1" >&2
                      shift
                      ;;
                  *)
                      RECIPIENTS+=("$1")
                      shift
                      ;;
              esac
          done

          if ! printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -e . >/dev/null 2>&1; then
              echo "pushover-mail: invalid --pushover-json payload" >&2
              exit 1
          fi

          TEMP_DIR=$(${pkgs.coreutils}/bin/mktemp -d)
          trap "${pkgs.coreutils}/bin/rm -rf '$TEMP_DIR'" EXIT

          MAIL_FILE="$TEMP_DIR/mail.txt"
          ${pkgs.coreutils}/bin/touch "$MAIL_FILE"

          while IFS= read -r line || [[ -n "$line" ]]; do
              if [[ "$IGNORE_DOT" != "true" && "$line" == "." ]]; then
                  break
              fi
              printf '%s\n' "$line" >> "$MAIL_FILE"
          done

          SUBJECT=$(${pkgs.gawk}/bin/awk '
            BEGIN {
              found = 0
            }
            $0 == "" {
              exit
            }
            tolower($0) ~ /^subject:[[:space:]]*/ {
              line = $0
              sub(/^[^:]*:[[:space:]]*/, "", line)
              print line
              found = 1
              next
            }
          ' "$MAIL_FILE")

          BODY=$(${pkgs.gawk}/bin/awk '
            BEGIN {
              found = 0
            }
            found {
              print
              next
            }
            $0 == "" {
              found = 1
            }
          ' "$MAIL_FILE")

          CONFIG_TITLE=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r '.title // empty')
          CONFIG_MESSAGE=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r '.message // empty')
          CONFIG_TYPE=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r '.type // empty')
          CONFIG_PRIORITY=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r 'if .priority == null then "" else (.priority | tostring) end')
          CONFIG_URL=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r '.url // empty')
          CONFIG_URL_TITLE=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r '.urlTitle // empty')
          CONFIG_HTML=$(printf '%s' "$PUSHOVER_JSON" | ${pkgs.jq}/bin/jq -r 'if .html then "true" else "false" end')

          FINAL_TITLE="$CONFIG_TITLE"
          if [[ -z "$FINAL_TITLE" ]]; then
              FINAL_TITLE="$SUBJECT"
          fi
          if [[ -z "$FINAL_TITLE" ]]; then
              FINAL_TITLE="Mail notification"
          fi
          if [[ -z "$CONFIG_TYPE" ]]; then
              FINAL_TITLE="✉️ $FINAL_TITLE"
          fi

          FINAL_MESSAGE="$CONFIG_MESSAGE"
          if [[ -z "$FINAL_MESSAGE" ]]; then
              FINAL_MESSAGE="$BODY"
          fi
          if [[ -z "$FINAL_MESSAGE" ]]; then
              FINAL_MESSAGE="$SUBJECT"
          fi
          if [[ -z "$FINAL_MESSAGE" ]]; then
              FINAL_MESSAGE="(empty message)"
          fi

          if [[ -n "$ENVELOPE_FROM" ]]; then
              FINAL_MESSAGE=$(printf 'From: %s\n%s' "$ENVELOPE_FROM" "$FINAL_MESSAGE")
          fi

          CMD=(
            "${pushoverSendPackage}/bin/pushover-send"
            --title "$FINAL_TITLE"
            --message "$FINAL_MESSAGE"
          )

          if [[ -n "$CONFIG_TYPE" ]]; then
              CMD+=(--type "$CONFIG_TYPE")
          fi

          if [[ -n "$CONFIG_PRIORITY" ]]; then
              CMD+=(--priority "$CONFIG_PRIORITY")
          fi

          if [[ -n "$CONFIG_URL" ]]; then
              CMD+=(--url "$CONFIG_URL")
          fi

          if [[ -n "$CONFIG_URL_TITLE" ]]; then
              CMD+=(--url-title "$CONFIG_URL_TITLE")
          fi

          if [[ "$CONFIG_HTML" == "true" ]]; then
              CMD+=(--html)
          fi

          exec "''${CMD[@]}"
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

          nx.linux.notifications.pushover.mkMailWrapper =
            {
              title ? null,
              message ? null,
              type ? null,
              priority ? null,
              url ? null,
              urlTitle ? null,
              html ? false,
              path ? null,
            }:
            let
              script = config.nx.linux.notifications.pushover.mailScript;
              scriptCmd =
                if !self.isEnabled then
                  null
                else if path != null then
                  path
                else if script != null then
                  "${script}/bin/pushover-mail"
                else
                  "pushover-mail";
              wrapperConfig = lib.filterAttrs (_: v: v != null) {
                inherit
                  title
                  message
                  type
                  priority
                  url
                  urlTitle
                  ;
                html = if html then true else null;
              };
            in
            "${
              pkgs.writeShellScriptBin "pushover-mail-wrapper" (
                if scriptCmd == null then
                  ''
                    exit 0
                  ''
                else
                  ''
                    exec > >(${pkgs.systemd}/bin/systemd-cat -t pushover-mail-wrapper -p info) 2>&1
                    ${lib.escapeShellArg scriptCmd} --pushover-json ${lib.escapeShellArg (builtins.toJSON wrapperConfig)} "$@"
                  ''
              )
            }/bin/pushover-mail-wrapper";
        };

      linux.enabled = config: {
        nx.linux.notifications.pushover.script = pushoverSendScript config;
        nx.linux.notifications.pushover.mailScript =
          pushoverMailScript config config.nx.linux.notifications.pushover.script;
      };

      linux.home =
        { enableE2EEncryption, ... }:
        {
          home.packages = lib.optionals (!enableE2EEncryption) [
            (pkgs.writeShellScriptBin "pushover-create-e2e-key" ''
              ${pkgs.openssl}/bin/openssl rand -hex 32
            '')
          ];
        };

      linux.system =
        {
          config,
          enableSendmail,
          enableE2EEncryption,
          ...
        }:
        let
          hostname = self.host.hostname;
          mainUser = config.users.users.${self.host.mainUser.username};
          mainUserGroup = mainUser.group;
          userNotifyEnabled = self.isModuleEnabled "notifications.user-notify";
        in
        {
          assertions = lib.optionals enableSendmail [
            {
              assertion = !config.nx.linux.mail.sendmail.enable;
              message = "pushover.enableSendmail and linux.mail.sendmail are mutually exclusive!";
            }
            {
              assertion = !config.services.postfix.enable;
              message = "pushover.enableSendmail and postfix are mutually exclusive!";
            }
          ];

          security.wrappers = lib.optionalAttrs enableSendmail {
            "sendmail" = {
              source = "${config.nx.linux.notifications.pushover.mailScript}/bin/pushover-mail";
              owner = "root";
              group = "root";
              permissions = "u+rwx,g+rx,o+rx";
            };
          };
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

          sops.secrets."pushover-e2e-key" = lib.mkIf enableE2EEncryption {
            format = "binary";
            sopsFile = self.config.secretsPath "pushover-e2e-key";
            mode = "0400";
            owner = "root";
            group = "root";
          };

          sops.secrets."pushover-e2e-key-${self.host.mainUser.username}" = lib.mkIf enableE2EEncryption {
            format = "binary";
            sopsFile = self.config.secretsPath "pushover-e2e-key";
            mode = "0440";
            owner = "root";
            group = mainUserGroup;
            path = "/run/pushover-e2e-key-${self.host.mainUser.username}";
          };

          environment.systemPackages = [
            config.nx.linux.notifications.pushover.script
            config.nx.linux.notifications.pushover.mailScript
            pkgs.curl
            (pkgs.writeShellScriptBin "pushover-run" ''
              if [[ $# -eq 0 ]]; then
                exit 0
              fi

              if ! command -v "$1" >/dev/null 2>&1; then
                echo "pushover-run: command not found: $1" >&2
                exit 127
              fi

              _start=$(${pkgs.coreutils}/bin/date +%s)
              "$@"
              _exit=$?
              _elapsed=$(( $(${pkgs.coreutils}/bin/date +%s) - _start ))

              if [[ $_elapsed -ge 3600 ]]; then
                _dur="$((_elapsed / 3600))h $(((_elapsed % 3600) / 60))m $((_elapsed % 60))s"
              elif [[ $_elapsed -ge 60 ]]; then
                _dur="$((_elapsed / 60))m $((_elapsed % 60))s"
              else
                _dur="''${_elapsed}s"
              fi

              if [[ $_exit -eq 0 ]]; then
                _type=success
              else
                _type=failed
              fi

              _cmd_escaped=$(printf '%s' "$*" | ${pkgs.gnused}/bin/sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
              _body=$(printf '<b>Command:</b> %s\n<b>Duration:</b> %s\n<b>Exit Code:</b> %s' "''${_cmd_escaped}" "''${_dur}" "''${_exit}")

              ${config.nx.linux.notifications.pushover.script}/bin/pushover-send \
                --title "Run: $(${pkgs.coreutils}/bin/basename "$1")" \
                --message "''${_body}" \
                --type "''${_type}" \
                --html \
                >/dev/null 2>&1 || true
              ${lib.optionalString userNotifyEnabled ''
                _notify_title="Run: $(${pkgs.coreutils}/bin/basename "$1")"
                _notify_body=$(printf '<u>Command:</u> %s\n<u>Duration:</u> %s\n<u>Exit Code:</u> %s' "$*" "''${_dur}" "''${_exit}")
                _notify_priority="user.info"
                if [[ ''${_exit} -ne 0 ]]; then
                  _notify_priority="user.err"
                fi
                _notify_icon="checkmark"
                if [[ ''${_exit} -ne 0 ]]; then
                  _notify_icon="dialog-error"
                fi
                _notify_payload=$(${pkgs.jq}/bin/jq -n \
                  --arg t "''${_notify_title}" \
                  --arg b "''${_notify_body}" \
                  --arg i "''${_notify_icon}" \
                  '{"title":$t,"body":$b,"icon":$i}')
                ${pkgs.util-linux}/bin/logger -p "''${_notify_priority}" -t nx-user-notify "JSON-DATA::''${_notify_payload}"
              ''}
              exit ''${_exit}
            '')
          ];
        };
    };
}
