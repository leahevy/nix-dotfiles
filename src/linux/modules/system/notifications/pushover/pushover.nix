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
rec {
  name = "pushover";

  group = "notifications";
  input = "linux";
  namespace = "system";

  settings = {
    defaultPriority = 0;
    pushoverAPIEndpoint = "https://api.pushover.net/1/messages.json";
  };

  custom = {
    pushoverSendScript = pkgs.writeShellScriptBin "pushover-send" ''
      set -euo pipefail

      TITLE=""
      MESSAGE=""
      PRIORITY="${toString self.settings.defaultPriority}"
      PRIORITY_SET=false
      TYPE=""
      URL=""
      HTML_MODE=false
      DEBUG_MODE=false
      EXTRA_ARGS=()

      while [[ $# -gt 0 ]]; do
          case $1 in
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
              --html)
                  HTML_MODE=true
                  shift
                  ;;
              --debug)
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
                  echo "Usage: $0 --title <title> --message <message> [--priority <priority>] [--type <type>] [--url <url>] [--html] [--debug] [-- <extra-pushover-args>]" >&2
                  echo "Types: started, stopped, failed, warn, success, info, debug, emerg" >&2
                  exit 1
                  ;;
          esac
      done

      if [[ -z "$TITLE" || -z "$MESSAGE" ]]; then
          echo "Error: --title and --message are required" >&2
          echo "Usage: $0 --title <title> --message <message> [--priority <priority>] [--type <type>] [--url <url>] [--html] [--debug] [-- <extra-pushover-args>]" >&2
          echo "Types: started, stopped, failed, warn, success, info, debug, emerg" >&2
          exit 1
      fi

      if [[ -n "$TYPE" && "$PRIORITY_SET" == "false" ]]; then
          case "$TYPE" in
              started) PRIORITY="-1" ;;
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
      EOF

      if [[ "$PRIORITY" == "2" ]]; then
          echo "form = \"retry=900\"" >> "$TEMP_CONFIG"
          echo "form = \"expire=10800\"" >> "$TEMP_CONFIG"
      fi

      if [[ -n "$URL" ]]; then
          ESCAPED_URL=$(escape_for_curl "$URL")
          echo "form = \"url=$ESCAPED_URL\"" >> "$TEMP_CONFIG"
      fi

      for arg in "''${EXTRA_ARGS[@]}"; do
          ESCAPED_ARG=$(escape_for_curl "$arg")
          echo "form = \"$ESCAPED_ARG\"" >> "$TEMP_CONFIG"
      done

      if [[ "$DEBUG_MODE" == "true" ]]; then
          echo "=== DEBUG: Curl config file content ===" >&2
          ${pkgs.coreutils}/bin/cat "$TEMP_CONFIG" >&2
          echo "=== END DEBUG ===" >&2
      fi

      for attempt in {1..5}; do
          if ${pkgs.curl}/bin/curl -fsS -m 30 --connect-timeout 10 -o /dev/null --config "$TEMP_CONFIG" ${self.settings.pushoverAPIEndpoint}; then
              exit 0
          else
              exit_code=$?
              if [[ $attempt -lt 5 ]]; then
                  sleep_time=$((attempt * 2))
                  echo "Pushover API call failed (attempt $attempt/5), retrying in $sleep_time seconds..." >&2
                  ${pkgs.coreutils}/bin/sleep $sleep_time
              else
                  echo "Pushover API call failed after 5 attempts" >&2
                  exit $exit_code
              fi
          fi
      done
    '';
  };

  configuration =
    context@{ config, options, ... }:
    let
      hostname = self.host.hostname;
      mainUser = config.users.users.${self.host.mainUser.username};
      mainUserGroup = mainUser.group;
      pushoverSendScript = custom.pushoverSendScript;
    in
    {

      sops.secrets."pushover-user" = {
        format = "binary";
        sopsFile = self.config.secretsPath "pushover-user";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      sops.secrets."${hostname}-pushover-token" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "pushover-token";
        mode = "0400";
        owner = "root";
        group = "root";
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
        pushoverSendScript
        pkgs.curl
      ];
    };
}
