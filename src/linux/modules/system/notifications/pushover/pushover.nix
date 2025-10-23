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

  defaults = {
    defaultPriority = 0;
    pushoverAPIEndpoint = "https://api.pushover.net/1/messages.json";
  };

  custom = {
    pushoverSendScript = pkgs.writeShellScriptBin "pushover-send" ''
      set -euo pipefail

      TITLE=""
      MESSAGE=""
      PRIORITY="${toString defaults.defaultPriority}"
      PRIORITY_SET=false
      TYPE=""
      URL=""
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
              --)
                  shift
                  EXTRA_ARGS=("$@")
                  break
                  ;;
              *)
                  echo "Unknown option: $1" >&2
                  echo "Usage: $0 --title <title> --message <message> [--priority <priority>] [--type <type>] [--url <url>] [-- <extra-pushover-args>]" >&2
                  echo "Types: started, stopped, failed, warn, success, info, debug, emerg" >&2
                  exit 1
                  ;;
          esac
      done

      if [[ -z "$TITLE" || -z "$MESSAGE" ]]; then
          echo "Error: --title and --message are required" >&2
          echo "Usage: $0 --title <title> --message <message> [--priority <priority>] [--type <type>] [--url <url>] [-- <extra-pushover-args>]" >&2
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

      TEMP_DIR=$(mktemp -d)
      TEMP_CONFIG="$TEMP_DIR/curl-config"

      trap "rm -rf '$TEMP_DIR'" EXIT

      touch "$TEMP_CONFIG"
      chmod 600 "$TEMP_CONFIG"

      cat > "$TEMP_CONFIG" <<EOF
      form = "token=$(cat "$TOKEN_FILE")"
      form = "user=$(cat "$USER_FILE")"
      form = "title=$FORMATTED_TITLE [${self.host.hostname}]"
      form = "message=$MESSAGE"
      form = "priority=$PRIORITY"
      EOF

      if [[ "$PRIORITY" == "2" ]]; then
          echo "form = \"retry=900\"" >> "$TEMP_CONFIG"
          echo "form = \"expire=10800\"" >> "$TEMP_CONFIG"
      fi

      if [[ -n "$URL" ]]; then
          echo "form = \"url=$URL\"" >> "$TEMP_CONFIG"
      fi

      for arg in "''${EXTRA_ARGS[@]}"; do
          echo "form = \"$arg\"" >> "$TEMP_CONFIG"
      done

      ${pkgs.curl}/bin/curl -fsS -m 30 --connect-timeout 10 --retry 5 --retry-delay 2 --retry-max-time 60 -o /dev/null --config "$TEMP_CONFIG" ${defaults.pushoverAPIEndpoint}
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
