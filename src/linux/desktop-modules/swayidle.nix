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
  name = "swayidle";

  group = "desktop-modules";
  input = "linux";

  options = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.swaylock;
      description = "Screen locker package to use.";
    };
    commandline = lib.mkOption {
      type = lib.types.str;
      default = "swaylock --daemonize";
      description = "Command line used to invoke the screen locker.";
    };
    autoLockOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to lock the session once on login.";
    };
    baseTimeoutSeconds = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Idle seconds before the screen locks.";
    };
    turnOnMonitorsCommand = lib.mkOption {
      type = lib.types.str;
      default = "true";
      description = "Command to turn monitors back on when resuming from the monitor off timeout.";
    };
    turnOffMonitorsCommand = lib.mkOption {
      type = lib.types.str;
      default = "true";
      description = "Command to turn monitors off after twice the base idle timeout.";
    };
    scriptsOnLock = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands to run when the session locks or before sleep.";
    };
    scriptsOnUnlock = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands to run when the session unlocks or after resume.";
    };
  };

  module = {
    linux.enabled = config: {
      nx.linux.desktop.common.graphicalSessionServices = [ "swayidle" ];
    };

    ifEnabled.linux.desktop.niri.home =
      config:
      let
        toggleSwayidleScript = pkgs.writeShellScript "toggle-swayidle" ''
          #!/usr/bin/env bash
          DISABLE_FILE="/tmp/.nx-no-swayidle"

          if [[ -f "$DISABLE_FILE" ]]; then
            rm "$DISABLE_FILE"
            ${self.notifyUser {
              inherit pkgs;
              title = "Swayidle";
              body = "Timeout commands enabled";
              icon = "system-suspend";
              urgency = "normal";
              validation = { inherit config; };
            }}
          else
            touch "$DISABLE_FILE"
            ${self.notifyUser {
              inherit pkgs;
              title = "Swayidle";
              body = "Timeout commands disabled";
              icon = "system-lock-screen";
              urgency = "normal";
              validation = { inherit config; };
            }}
          fi
        '';
      in
      {
        programs.niri = {
          settings = {
            binds = with config.lib.niri.actions; {
              "Mod+T" = {
                action = spawn-sh (toString toggleSwayidleScript);
                hotkey-overlay.title = "UI:Toggle swayidle timeouts";
              };
            };
          };
        };
      };

    home =
      {
        config,
        package,
        commandline,
        autoLockOnLogin,
        baseTimeoutSeconds,
        turnOnMonitorsCommand,
        turnOffMonitorsCommand,
        scriptsOnLock,
        scriptsOnUnlock,
        ...
      }:
      let
        theme = config.nx.preferences.theme;

        colorReplacements = {
          "<RING_COLOR>" = "${lib.removePrefix "#" theme.colors.main.backgrounds.primary.html}55";
          "<INSIDE_WRONG_COLOR>" = lib.removePrefix "#" theme.colors.main.backgrounds.primary.html;
          "<TEXT_WRONG_COLOR>" = lib.removePrefix "#" theme.colors.semantic.error.html;
          "<INSIDE_VER_COLOR>" = lib.removePrefix "#" theme.colors.main.backgrounds.primary.html;
          "<TEXT_VER_COLOR>" = lib.removePrefix "#" theme.colors.semantic.success.html;
          "<RING_VER_COLOR>" = lib.removePrefix "#" theme.colors.semantic.success.html;
          "<RING_WRONG_COLOR>" = lib.removePrefix "#" theme.colors.semantic.error.html;
          "<RING_CLEAR_COLOR>" = lib.removePrefix "#" theme.colors.main.base.blue.html;
          "<TEXT_CLEAR_COLOR>" = lib.removePrefix "#" theme.colors.main.base.blue.html;
          "<INSIDE_CLEAR_COLOR>" = lib.removePrefix "#" theme.colors.main.backgrounds.primary.html;
        };

        replaceColorPlaceholders =
          str:
          builtins.foldl' (
            acc: placeholderColor:
            builtins.replaceStrings [ placeholderColor ] [ colorReplacements.${placeholderColor} ] acc
          ) str (builtins.attrNames colorReplacements);

        resolvedCommandline = replaceColorPlaceholders commandline;

        unreplacedPlaceholders = builtins.match ".*<[A-Z_]+>.*" resolvedCommandline;
        commandlineValidated =
          if unreplacedPlaceholders != null then
            throw "swayidle: commandline contains unreplaced placeholders: ${resolvedCommandline}"
          else
            resolvedCommandline;

        wrapTimeoutCommand =
          command:
          pkgs.writeShellScript "swayidle-timeout-wrapper" ''
            #!/usr/bin/env bash
            if [[ ! -f "/tmp/.nx-no-swayidle" ]]; then
              ${command}
            fi
          '';
      in
      {
        home.packages =
          with pkgs;
          [
            swayidle
          ]
          ++ [ package ];

        home.file."${defs.binDir}/scripts/swaylock-wrapper-daemon" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            exec "${self.binDir}/scripts/swaylock-wrapper" "$@" &
          '';
        };

        home.file."${defs.binDir}/scripts/swaylock-wrapper" = {
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
            ${pkgs.systemd}/bin/loginctl unlock-session || true
          '';
        };

        services.swayidle =
          let
            wrapperCommand = "${self.binDir}/scripts/swaylock-wrapper-daemon ${package}/bin/${commandlineValidated}";
            wrappedLockCommand = toString (wrapTimeoutCommand wrapperCommand);
            wrappedMonitorOffCommand = toString (
              wrapTimeoutCommand (lib.concatStringsSep ";" [ turnOffMonitorsCommand ])
            );
            lockEventScript = pkgs.writeShellScript "swayidle-lock-event" ''
              ${wrapperCommand}
              ${lib.concatMapStringsSep "\n" (cmd: "${cmd} || true") scriptsOnLock}
            '';
            unlockEventScript = pkgs.writeShellScript "swayidle-unlock-event" ''
              ${lib.concatMapStringsSep "\n" (cmd: "${cmd} || true") scriptsOnUnlock}
            '';
          in
          {
            enable = true;
            systemdTargets = [ "graphical-session.target" ];
            timeouts = [
              {
                timeout = baseTimeoutSeconds;
                command = wrappedLockCommand;
              }
              {
                timeout = baseTimeoutSeconds * 2;
                command = wrappedMonitorOffCommand;
                resumeCommand = turnOnMonitorsCommand;
              }
            ];
            events = {
              before-sleep = toString lockEventScript;
              lock = toString lockEventScript;
              unlock = toString unlockEventScript;
              after-resume = toString unlockEventScript;
            };
          };

        systemd.user.services.nx-lock-on-login = lib.mkIf autoLockOnLogin {
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
  };
}
