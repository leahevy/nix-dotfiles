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
  name = "sops";
  group = "core";
  input = "build";

  module = {
    home = config: {
      sops = {
        defaultSopsFile =
          if self.user.isStandalone then
            self.config.secretsPath "standalone-secrets.yaml"
          else
            self.config.secretsPath "user-secrets.yaml";

        age.keyFile =
          if self.user.isStandalone then
            "${config.xdg.configHome}/sops/age/keys.txt"
          else
            self.persistPath "${self.user.home}/.config/sops/age/keys.txt";
      };

      home.sessionVariables = {
        SOPS_AGE_KEY_FILE =
          if self.user.isStandalone then
            "${config.xdg.configHome}/sops/age/keys.txt"
          else
            self.persistPath "${self.user.home}/.config/sops/age/keys.txt";
      };

      systemd.user.services.sops-nix = lib.mkIf self.isLinux {
        Service = {
          Environment = lib.mkForce [
            "GNUPGHOME=/nonexistent"
          ];
        };
      };
    };

    linux.home = config: {
      home.file.".local/bin/sops-restart" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          unit="sops-nix.service"
          lock_base="''${XDG_RUNTIME_DIR:-/tmp}"
          lock_dir="$lock_base/sops-restart.lock"
          min_age_secs=3

          cleanup() {
            rmdir "$lock_dir" >/dev/null 2>&1 || true
          }

          if ! mkdir "$lock_dir" >/dev/null 2>&1; then
            echo "Another sops-restart is already running!" >&2
            exit 1
          fi
          trap cleanup EXIT INT TERM

          if ! systemctl --user show "$unit" >/dev/null 2>&1; then
            echo "Unit $unit not found!" >&2
            exit 1
          fi

          active_state="$(systemctl --user show "$unit" -p ActiveState --value)"
          sub_state="$(systemctl --user show "$unit" -p SubState --value)"

          now_us="$(
            awk '{ printf("%d\n", $1 * 1000000) }' /proc/uptime 2>/dev/null || echo 0
          )"
          change_us="$(systemctl --user show "$unit" -p StateChangeTimestampMonotonic --value 2>/dev/null || echo 0)"
          if [[ "$now_us" =~ ^[0-9]+$ ]] && [[ "$change_us" =~ ^[0-9]+$ ]] && (( change_us > 0 )); then
            age_us=$(( now_us - change_us ))
            if (( age_us >= 0 )) && (( age_us < min_age_secs * 1000000 )); then
              echo "$unit changed state recently, skipping restart." >&2
              exit 0
            fi
          fi

          if [[ "$active_state" != "inactive" || "$sub_state" != "dead" ]]; then
            echo "$unit is $active_state($sub_state)!" >&2
            echo
            read -r -p "Restart anyway? [Y/n] " reply
            case "$reply" in
              ""|[yY]|[yY][eE][sS]) ;;
              *) echo "Aborted!" >&2; exit 1 ;;
            esac
          fi

          if ! systemctl --user restart "$unit"; then
            echo "Restart failed! Showing status and recent logs:" >&2
            echo
            journalctl --user -u "$unit" -n 20 --no-pager >&2 || true
            exit 1
          fi
        '';
      };
    };

    system = config: {
      sops = {
        defaultSopsFile = self.config.secretsPath "host-secrets.yaml";
        age.keyFile = self.persistPath "etc/sops/age/keys.txt";
      };
    };
  };
}
