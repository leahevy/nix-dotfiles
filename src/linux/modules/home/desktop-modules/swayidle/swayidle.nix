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
  name = "swayidle";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  defaults = {
    package = pkgs.swaylock;
    commandline = "swaylock --daemonize";
    auto-lock-on-login = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages =
        with pkgs;
        [
          swayidle
        ]
        ++ [ self.settings.package ];

      home.file.".local/bin/scripts/swaylock-wrapper-daemon" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec "${self.user.home}/.local/bin/scripts/swaylock-wrapper" "$@" &
        '';
      };

      home.file.".local/bin/scripts/swaylock-wrapper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          UNLOCK_TIME_FILE="/tmp/swaylock_unlock_time"
          SCRIPT_NAME="swaylock-wrapper"

          echo "swaylock-wrapper called with args: $*"

          if ${pkgs.procps}/bin/pgrep -f "$SCRIPT_NAME" | grep -v "$$" >/dev/null 2>&1; then
              echo "Another swaylock-wrapper instance is running, skipping"
              exit 0
          fi

          if [[ -f "$UNLOCK_TIME_FILE" ]]; then
              LAST_UNLOCK=$(${pkgs.coreutils}/bin/cat "$UNLOCK_TIME_FILE" 2>/dev/null || echo "0")
              CURRENT_TIME=$(${pkgs.coreutils}/bin/date +%s)
              TIME_DIFF=$((CURRENT_TIME - LAST_UNLOCK))

              if [[ $TIME_DIFF -lt 5 ]]; then
                  echo "Last unlock was $TIME_DIFF seconds ago, skipping lock"
                  exit 0
              fi
          fi

          echo "Starting swaylock: $*"

          "$@"
          echo "swaylock command returned with exit code: $?"

          ${pkgs.coreutils}/bin/sleep 0.8

          if ${pkgs.procps}/bin/pgrep -x "swaylock" >/dev/null 2>&1; then
              echo "swaylock process found, starting monitoring..."
          else
              echo "No swaylock process found after startup"
              exit 1
          fi

          echo "Monitoring for swaylock process..."
          while ${pkgs.procps}/bin/pgrep -x "swaylock" >/dev/null 2>&1; do
              ${pkgs.coreutils}/bin/sleep 1
          done

          echo "swaylock process disappeared, recording unlock time..."
          ${pkgs.coreutils}/bin/date +%s > "$UNLOCK_TIME_FILE"
          echo "Unlock detected, recorded timestamp: $(${pkgs.coreutils}/bin/cat "$UNLOCK_TIME_FILE")"
        '';
      };

      services.swayidle =
        let
          wrapperCommand = "${self.user.home}/.local/bin/scripts/swaylock-wrapper-daemon ${self.settings.package}/bin/${self.settings.commandline}";
        in
        {
          enable = true;
          systemdTarget = "graphical-session.target";
          timeouts = [
            {
              timeout = 300;
              command = wrapperCommand;
            }
            {
              timeout = 600;
              command = lib.concatStringsSep ";" [ self.settings.turnOffMonitorsCommand ];
              resumeCommand = self.settings.turnOnMonitorsCommand;
            }
          ];
          events = [
            {
              event = "before-sleep";
              command = wrapperCommand;
            }
            {
              event = "lock";
              command = wrapperCommand;
            }
          ];
        };

      systemd.user.services.nx-lock-on-login = lib.mkIf self.settings.auto-lock-on-login {
        Unit = {
          Description = "Lock screen once on login";
          After = [
            "graphical-session.target"
            "niri.service"
            "swayidle.service"
            "nx-swaybg.service"
          ];
          Wants = [
            "niri.service"
            "swayidle.service"
            "nx-swaybg.service"
          ];
        };

        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStartPre = [
            "/bin/sh -c 'for i in {1..30}; do ${pkgs.niri}/bin/niri msg workspaces >/dev/null 2>&1 && exit 0 || sleep 1; done; exit 1'"
            "/bin/sh -c 'sleep 2'"
          ];
          ExecStart = "loginctl lock-session";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
