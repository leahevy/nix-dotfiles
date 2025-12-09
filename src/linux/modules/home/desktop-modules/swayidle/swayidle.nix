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

  settings = {
    package = pkgs.swaylock;
    commandline = "swaylock --daemonize";
    auto-lock-on-login = false;
    baseTimeoutSeconds = 600;
    turnOnMonitorsCommand = "true";
    turnOffMonitorsCommand = "true";
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");

      wrapTimeoutCommand =
        command:
        pkgs.writeShellScript "swayidle-timeout-wrapper" ''
          #!/usr/bin/env bash
          if [[ ! -f "/tmp/.nx-no-swayidle" ]]; then
            ${command}
          fi
        '';

      toggleSwayidleScript = pkgs.writeShellScript "toggle-swayidle" ''
        #!/usr/bin/env bash
        DISABLE_FILE="/tmp/.nx-no-swayidle"

        if [[ -f "$DISABLE_FILE" ]]; then
          rm "$DISABLE_FILE"
          ${pkgs.libnotify}/bin/notify-send "Swayidle" "Timeout commands enabled" --icon=system-suspend
        else
          touch "$DISABLE_FILE"
          ${pkgs.libnotify}/bin/notify-send "Swayidle" "Timeout commands disabled" --icon=system-lock-screen
        fi
      '';
    in
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
          wrappedLockCommand = toString (wrapTimeoutCommand wrapperCommand);
          wrappedMonitorOffCommand = toString (
            wrapTimeoutCommand (lib.concatStringsSep ";" [ self.settings.turnOffMonitorsCommand ])
          );
        in
        {
          enable = true;
          systemdTarget = "graphical-session.target";
          timeouts = [
            {
              timeout = self.settings.baseTimeoutSeconds;
              command = wrappedLockCommand;
            }
            {
              timeout = self.settings.baseTimeoutSeconds * 2;
              command = wrappedMonitorOffCommand;
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

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+T" = {
              action = spawn-sh (toString toggleSwayidleScript);
              hotkey-overlay.title = "UI:Toggle swayidle timeouts";
            };
          };
        };
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
