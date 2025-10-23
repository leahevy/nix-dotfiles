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
  name = "auto-upgrades";

  group = "system";
  input = "linux";
  namespace = "system";

  defaults = {
    schedule = "18:45:10";
    allowReboot = true;
    rebootWindow = {
      lower = "23:00";
      upper = "07:00";
    };
    preNotificationTimeMinutes = 15;
    maxNetworkRetries = 30;
    waitForNetwork = true;
    dryRun = true;
    pushoverNotifications = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      nxcoreDir = "${self.host.mainUser.home}/.config/nx/nxcore";
      nxconfigDir = "${self.host.mainUser.home}/.config/nx/nxconfig";

      profileName = "${self.host.hostname}--${self.host.architecture}";

      coreRepoHost = builtins.head (builtins.match "https://([^/]+)/.*" self.variables.coreRepoIsoUrl);
      configRepoHost = builtins.head (
        builtins.match "https://([^/]+)/.*" self.variables.configRepoIsoUrl
      );

      gitEnv = "GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_SSH_COMMAND='ssh -i /run/nx-auto-upgrade-ssh-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'";

      logScript =
        level: message:
        let
          userNotifyEnabled = (self.user.isModuleEnabled "notifications.user-notify");
          pushoverEnabled =
            (self.isModuleEnabled "notifications.pushover") && self.settings.pushoverNotifications;

          userNotifyMessage =
            if userNotifyEnabled then
              if lib.hasPrefix "STARTED:" message then
                "Auto-Upgrade (starting): ${lib.removePrefix "STARTED: " message}"
              else if lib.hasPrefix "SUCCESS:" message then
                "Auto-Upgrade (completed): ${lib.removePrefix "SUCCESS: " message}"
              else if lib.hasPrefix "FAILURE:" message then
                "Auto-Upgrade (failed): ${lib.removePrefix "FAILURE: " message}"
              else if lib.hasPrefix "INFO:" message then
                "Auto-Upgrade (info): ${lib.removePrefix "INFO: " message}"
              else if lib.hasPrefix "NOTICE:" message then
                "Auto-Upgrade (notice): ${lib.removePrefix "NOTICE: " message}"
              else
                "Auto-Upgrade: ${message}"
            else
              "";

          pushoverType =
            if lib.hasPrefix "STARTED:" message then
              "started"
            else if lib.hasPrefix "SUCCESS:" message then
              "success"
            else if lib.hasPrefix "SUCCESS-REBOOT-NOW:" message then
              "warn"
            else if lib.hasPrefix "SUCCESS-REBOOT-LATER:" message then
              "success"
            else if lib.hasPrefix "INFO:" message && lib.hasSuffix "skipping upgrade" message then
              "info"
            else if lib.hasPrefix "FAILURE:" message then
              "failed"
            else
              null;

          shouldSendPushover = pushoverEnabled && pushoverType != null;

          pushoverMessage =
            if lib.hasPrefix "STARTED:" message then
              lib.removePrefix "STARTED: " message
            else if lib.hasPrefix "SUCCESS:" message then
              lib.removePrefix "SUCCESS: " message
            else if lib.hasPrefix "SUCCESS-REBOOT-NOW:" message then
              lib.removePrefix "SUCCESS-REBOOT-NOW: " message
            else if lib.hasPrefix "SUCCESS-REBOOT-LATER:" message then
              lib.removePrefix "SUCCESS-REBOOT-LATER: " message
            else if lib.hasPrefix "INFO:" message && lib.hasSuffix "skipping upgrade" message then
              lib.removePrefix "INFO: " message
            else if lib.hasPrefix "FAILURE:" message then
              lib.removePrefix "FAILURE: " message
            else
              message;
        in
        ''
          ${lib.optionalString userNotifyEnabled ''${pkgs.util-linux}/bin/logger -p user.${level} -t nx-user-notify "${userNotifyMessage}"''}
          ${lib.optionalString shouldSendPushover ''pushover-send --title "Auto-Upgrade" --message "${pushoverMessage}" --type ${pushoverType} || true''}
          echo "${message}" ${if level == "err" then ">&2" else ""}
        '';

      checkNetworkScript = lib.optionalString self.settings.waitForNetwork ''
        ${pkgs.coreutils}/bin/echo "Checking network connectivity..."
        retries=0
        max_retries=${toString self.settings.maxNetworkRetries}

        for host in "${coreRepoHost}" "${configRepoHost}"; do
          ${pkgs.coreutils}/bin/echo "Testing connectivity to $host..."
          host_retries=0
          until ${pkgs.iputils}/bin/ping -c1 -q "$host" >/dev/null 2>&1; do
            host_retries=$((host_retries + 1))
            if [ $host_retries -ge $max_retries ]; then
              ${logScript "err" "FAILURE: Network connectivity to $host failed after $max_retries attempts"}
              exit 1
            fi
            ${pkgs.coreutils}/bin/echo "Host $host not reachable, waiting 30s... (attempt $host_retries/$max_retries)"
            ${pkgs.coreutils}/bin/sleep 30
          done
        done
      '';

      checkRepositoriesExistScript = ''
        check_repo_exists() {
          local repo_path="$1"
          local repo_name="$2"

          if [[ ! -d "$repo_path" ]]; then
            ${logScript "err" "FAILURE: Repository $repo_name not found at $repo_path"}
            exit 1
          fi

          if [[ ! -d "$repo_path/.git" ]]; then
            ${logScript "err" "FAILURE: Directory $repo_path is not a git repository"}
            exit 1
          fi
        }

        check_repo_exists "${nxcoreDir}" "nxcore"
        check_repo_exists "${nxconfigDir}" "nxconfig"
      '';

      checkGitWorktreesScript = ''
        check_git_clean() {
          local repo_path="$1"
          local repo_name="$2"

          cd "$repo_path"
          if [[ "$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git status --porcelain)" != "" ]]; then
            ${logScript "err" "FAILURE: Repository $repo_name has uncommitted changes"}
            exit 1
          fi
        }

        check_git_clean "${nxcoreDir}" "nxcore"
        check_git_clean "${nxconfigDir}" "nxconfig"
      '';

      checkForChangesScript = ''
        check_for_changes() {
          local repo_path="$1"
          local repo_name="$2"

          cd "$repo_path"
          ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git fetch origin >/dev/null 2>&1
          local local_commit=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse HEAD)
          local remote_commit=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse origin/main)

          if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git merge-base --is-ancestor "$local_commit" origin/main >/dev/null 2>&1; then
            ${logScript "err" "FAILURE: Repository $repo_name local commit is ahead of remote - development in progress"}
            exit 1
          fi

          if [[ "$local_commit" != "$remote_commit" ]]; then
            ${logScript "info" "INFO: Repository $repo_name has remote changes"}
            return 0
          else
            return 1
          fi
        }

        nxcore_changed=false
        nxconfig_changed=false

        if check_for_changes "${nxcoreDir}" "nxcore"; then
          nxcore_changed=true
        fi

        if check_for_changes "${nxconfigDir}" "nxconfig"; then
          nxconfig_changed=true
        fi

        if [[ "$nxcore_changed" == "false" && "$nxconfig_changed" == "false" ]]; then
          ${logScript "info" "INFO: No remote changes detected, skipping upgrade"}
          exit 0
        fi
      '';

      pullRepositoriesScript = ''
        pull_repo() {
          local repo_path="$1"
          local repo_name="$2"

          cd "$repo_path"
          ${logScript "info" "INFO: ${
            if self.settings.dryRun then "Would pull" else "Pulling"
          } latest changes for $repo_name"}

          ${
            if self.settings.dryRun then
              ''
                ${pkgs.coreutils}/bin/echo "Would execute: sudo -u ${self.host.mainUser.username} ${gitEnv} git pull origin main"
              ''
            else
              ''
                if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git pull origin main; then
                  ${logScript "err" "FAILURE: Failed to pull $repo_name repository"}
                  exit 1
                fi
                ${pkgs.coreutils}/bin/chown -R ${self.host.mainUser.username}:${self.host.mainUser.username} "$repo_path"
              ''
          }
        }

        pull_repo "${nxcoreDir}" "nxcore"
        pull_repo "${nxconfigDir}" "nxconfig"
      '';

      upgradeScript = ''
        ${logScript "info" "INFO: ${
          if self.settings.dryRun then "Would start" else "Starting"
        } system rebuild"}
        cd "${nxcoreDir}"

        PROFILE_PATH="${nxconfigDir}/profiles/nixos/${self.host.hostname}"

        export NIXOS_LABEL="auto-$(${pkgs.coreutils}/bin/date +%d%m.%H%M)"

        ${
          if self.settings.dryRun then
            ''
              ${pkgs.coreutils}/bin/echo "Would execute: nh os switch -H '${profileName}' . -- --impure --override-input config 'path:${nxconfigDir}' --override-input profile 'path:$PROFILE_PATH' --print-build-logs"
              ${logScript "info" "System rebuild command prepared"}
            ''
          else
            ''
              if ! ${pkgs.nh}/bin/nh os switch -H "${profileName}" . -- \
                --impure \
                --override-input config "path:${nxconfigDir}" \
                --override-input profile "path:$PROFILE_PATH" \
                --print-build-logs; then
                ${logScript "err" "FAILURE: System rebuild failed"}
                exit 1
              fi
              ${logScript "info" "SUCCESS: System rebuild completed successfully"}
            ''
        }
      '';

      checkRebootWindow = lib.optionalString (self.settings.rebootWindow != null) ''
        check_reboot_window() {
          local current_time="$(${pkgs.coreutils}/bin/date +%H:%M)"
          local lower="${self.settings.rebootWindow.lower}"
          local upper="${self.settings.rebootWindow.upper}"

          if [[ "''${lower}" < "''${upper}" ]]; then
            if [[ "''${current_time}" > "''${lower}" ]] && [[ "''${current_time}" < "''${upper}" ]]; then
              return 0
            fi
          else
            if [[ "''${current_time}" < "''${upper}" ]] || [[ "''${current_time}" > "''${lower}" ]]; then
              return 0
            fi
          fi
          return 1
        }
      '';

      rebootScript = lib.optionalString self.settings.allowReboot ''
        check_reboot_needed() {
          local booted_kernel="$(${pkgs.coreutils}/bin/readlink /run/booted-system/kernel)"
          local built_kernel="$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system/kernel)"
          local booted_initrd="$(${pkgs.coreutils}/bin/readlink /run/booted-system/initrd)"
          local built_initrd="$(${pkgs.coreutils}/bin/readlink /nix/var/nix/profiles/system/initrd)"

          if [[ "$booted_kernel" != "$built_kernel" || "$booted_initrd" != "$built_initrd" ]]; then
            return 0
          else
            return 1
          fi
        }

        ${checkRebootWindow}

        ${logScript "info" "Checking if reboot is needed"}
        if check_reboot_needed; then
          ${
            if self.settings.rebootWindow != null then
              ''
                if check_reboot_window; then
                  ${logScript "info" "SUCCESS-REBOOT-NOW: Reboot needed and within window - ${
                    if self.settings.dryRun then "would reboot" else "rebooting"
                  } in +1 minute"}
                  ${
                    if self.settings.dryRun then
                      ''${pkgs.coreutils}/bin/echo "Would execute: shutdown -r +1"''
                    else
                      ''${config.systemd.package}/bin/shutdown -r +1''
                  }
                else
                  ${logScript "info" "SUCCESS-REBOOT-LATER: Reboot needed but outside window (${self.settings.rebootWindow.lower}-${self.settings.rebootWindow.upper}) - ${
                    if self.settings.dryRun then "would create" else "creating"
                  } marker file"}
                  ${
                    if self.settings.dryRun then
                      ''${pkgs.coreutils}/bin/echo "Would create marker file: /run/nx-auto-upgrade-reboot-needed"''
                    else
                      ''
                        ${pkgs.coreutils}/bin/echo "$(${pkgs.coreutils}/bin/date)" > /run/nx-auto-upgrade-reboot-needed
                        ${pkgs.coreutils}/bin/chown root:root /run/nx-auto-upgrade-reboot-needed
                        ${pkgs.coreutils}/bin/chmod 600 /run/nx-auto-upgrade-reboot-needed
                      ''
                  }
                fi
              ''
            else
              ''
                ${logScript "info" "SUCCESS-REBOOT-NOW: Reboot needed - ${
                  if self.settings.dryRun then "would reboot" else "rebooting"
                } in +1 minute"}
                ${
                  if self.settings.dryRun then
                    ''${pkgs.coreutils}/bin/echo "Would execute: shutdown -r +1"''
                  else
                    ''${config.systemd.package}/bin/shutdown -r +1''
                }
              ''
          }
        else
          ${logScript "info" "SUCCESS: Auto-upgrade completed successfully, no reboot required"}
        fi
      '';

      delayedRebootScript = lib.optionalString self.settings.allowReboot ''
        reboot_marker="/run/nx-auto-upgrade-reboot-needed"

        if [[ ! -f "$reboot_marker" ]]; then
          exit 0
        fi

        ${checkRebootWindow}

        ${
          if self.settings.dryRun then
            ''
              ${logScript "info" "Would check reboot marker and reboot if in window"}
              ${pkgs.coreutils}/bin/echo "Would check marker file: $reboot_marker"
              ${pkgs.coreutils}/bin/echo "Would execute: shutdown -r +1"
            ''
          else if self.settings.rebootWindow != null then
            ''
              if check_reboot_window; then
                ${logScript "info" "INFO: Delayed reboot marker found and inside reboot window, rebooting in 1 minute"}
                ${config.systemd.package}/bin/shutdown -r +1
              fi
            ''
          else
            ''
              ${logScript "info" "INFO: Delayed reboot marker found, rebooting in 1 minute"}
              ${config.systemd.package}/bin/shutdown -r +1
            ''
        }
      '';

    in
    {
      sops.secrets.github-ssh-key = {
        format = "binary";
        sopsFile = self.config.secretsPath "github-ssh-key";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      systemd.services.nx-auto-upgrade-log-failure = {
        description = "Log NX Auto-Upgrade Failure";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = logScript "err" "FAILURE: Auto-upgrade failed - check journalctl -u nx-auto-upgrade";
      };

      systemd.services.nx-auto-upgrade-notify = {
        description = "NX Auto-Upgrade Pre-Notification";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };

        unitConfig = {
          OnSuccess = "nx-auto-upgrade-delayed.service";
        };

        script = logScript "info" "NOTICE: Auto-upgrade starting in ${builtins.toString self.settings.preNotificationTimeMinutes}M - avoid repository changes";
      };

      systemd.services.nx-auto-upgrade = {
        description = "NX Auto-Upgrade";

        restartIfChanged = false;
        unitConfig = {
          X-StopOnRemoval = false;
          OnFailure = "nx-auto-upgrade-log-failure.service";
        };

        serviceConfig = {
          Type = "oneshot";
          User = "root";
          LoadCredential = "github-ssh-key:${config.sops.secrets.github-ssh-key.path}";
          ExecStartPost = "${pkgs.coreutils}/bin/rm -f /run/nx-auto-upgrade-ssh-key";
          ExecStopPost = "${pkgs.writeShellScript "nx-auto-upgrade-stop-handler" ''
            if [ "$EXIT_CODE" = "killed" ]; then
              ${logScript "err" "FAILURE: Auto-upgrade was stopped/interrupted"}
            fi
            ${pkgs.coreutils}/bin/rm -f /run/nx-auto-upgrade-ssh-key
          ''}";
        };

        environment =
          config.nix.envVars
          // {
            inherit (config.environment.sessionVariables) NIX_PATH;
            HOME = "/root";
          }
          // config.networking.proxy.envVars;

        path =
          with pkgs;
          [
            coreutils
            git
            openssh
            config.nix.package.out
            nh
            sudo
            util-linux
            iputils
          ]
          ++
            lib.optionals (self.isModuleEnabled "notifications.pushover" && self.settings.pushoverNotifications)
              [
                (self.importFileFromOtherModuleSameInput {
                  inherit args self;
                  modulePath = "notifications.pushover";
                }).custom.pushoverSendScript
              ];

        script =
          "exec ${pkgs.systemd}/bin/systemd-inhibit --who=\"nx-auto-upgrade\" --what=\"idle:sleep:shutdown\" --why=\"System upgrade in progress\" "
          + pkgs.writeShellScript "nx-auto-upgrade-main" ''
            set -euo pipefail

            ${pkgs.coreutils}/bin/install -m 400 -o ${
              toString config.users.users.${self.host.mainUser.username}.uid
            } -g ${
              toString config.users.groups.${config.users.users.${self.host.mainUser.username}.group}.gid
            } "$CREDENTIALS_DIRECTORY/github-ssh-key" /run/nx-auto-upgrade-ssh-key

            ${pkgs.coreutils}/bin/sleep 15

            lock_dir="/tmp/.nx-deployment-lock"
            if [[ -d "$lock_dir" ]]; then
              ${logScript "err" "FAILURE: Another deployment is already running"}
              exit 1
            fi

            if ! ${pkgs.coreutils}/bin/mkdir "$lock_dir" 2>/dev/null; then
              ${logScript "err" "FAILURE: Failed to create deployment lock"}
              exit 1
            fi

            cleanup_lock() {
              ${pkgs.coreutils}/bin/rm -rf "$lock_dir" 2>/dev/null || true
            }
            trap cleanup_lock EXIT TERM

            ${pkgs.coreutils}/bin/sleep 45

            ${logScript "info" "STARTED: Auto-upgrade beginning"}
            ${pkgs.coreutils}/bin/sleep 5

            ${checkNetworkScript}
            ${checkRepositoriesExistScript}
            ${checkGitWorktreesScript}
            ${checkForChangesScript}
            ${pullRepositoriesScript}
            ${upgradeScript}
            ${rebootScript}
          '';

        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
      };

      systemd.timers.nx-auto-upgrade-notify = {
        description = "NX Auto-Upgrade Pre-Notification Timer";
        timerConfig = {
          OnCalendar = self.settings.schedule;
          RandomizedDelaySec = "5min";
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };

      systemd.services.nx-auto-upgrade-delayed = {
        description = "NX Auto-Upgrade (Delayed)";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep ${
            builtins.toString (self.settings.preNotificationTimeMinutes * 60)
          }";
          ExecStart = "${pkgs.systemd}/bin/systemctl start nx-auto-upgrade.service";
        };
      };

      systemd.services.nx-auto-upgrade-reboot-checker = lib.mkIf self.settings.allowReboot {
        description = "NX Auto-Upgrade Delayed Reboot Checker";

        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };

        path = with pkgs; [
          coreutils
          util-linux
          config.systemd.package
        ];

        script = delayedRebootScript;
        after = [ "multi-user.target" ];
      };

      systemd.timers.nx-auto-upgrade-reboot-checker = lib.mkIf self.settings.allowReboot {
        description = "NX Auto-Upgrade Delayed Reboot Checker Timer";
        timerConfig = {
          OnCalendar = "hourly";
          OnBootSec = "15min";
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };

      system.autoUpgrade.enable = lib.mkForce false;

    };
}
