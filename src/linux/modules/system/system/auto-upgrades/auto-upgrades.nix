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

  settings = {
    schedule = "18:45:10";
    allowReboot = true;
    rebootWindow = {
      lower = "01:00";
      upper = "03:00";
    };
    preNotificationTimeMinutes = 30;
    maxNetworkRetries = 30;
    waitForNetwork = true;
    dryRun = false;
    pushoverNotifications = true;
    verifySignatures = true;
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

      gitEnv = "GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null";

      logScript =
        level: message:
        let
          userNotifyEnabled = (self.user.isModuleEnabled "notifications.user-notify");
          pushoverEnabled =
            (self.isModuleEnabled "notifications.pushover") && self.settings.pushoverNotifications;

          userNotifyMessage =
            if userNotifyEnabled then
              if lib.hasPrefix "STARTED:" message then
                "Auto-Upgrade (starting)|system-software-install: ${lib.removePrefix "STARTED: " message}"
              else if lib.hasPrefix "SUCCESS:" message then
                "Auto-Upgrade (completed)|checkmark: ${lib.removePrefix "SUCCESS: " message}"
              else if lib.hasPrefix "SUCCESS-REBOOT-LATER:" message then
                "Auto-Upgrade (completed)|checkmark: ${lib.removePrefix "SUCCESS-REBOOT-LATER: " message}"
              else if lib.hasPrefix "FAILURE:" message then
                "Auto-Upgrade (failed)|dialog-error: ${lib.removePrefix "FAILURE: " message}"
              else if lib.hasPrefix "WARNING:" message then
                "Auto-Upgrade (warning)|dialog-warning: ${lib.removePrefix "WARNING: " message}"
              else if lib.hasPrefix "INFO:" message then
                if lib.hasSuffix "skipping upgrade" message then
                  "Auto-Upgrade (info)|stop: ${lib.removePrefix "INFO: " message}"
                else if lib.hasInfix "Borg backup" message then
                  "Auto-Upgrade (info)|system-software-install: ${lib.removePrefix "INFO: " message}"
                else
                  null
              else if lib.hasPrefix "NOTICE:" message then
                "Auto-Upgrade (notice)|system-software-install: ${lib.removePrefix "NOTICE: " message}"
              else
                "Auto-Upgrade|system-software-install: ${message}"
            else
              null;

          shouldSendUserNotify = userNotifyEnabled && userNotifyMessage != null;

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
            else if lib.hasPrefix "INFO:" message && lib.hasInfix "Borg backup" message then
              "info"
            else if lib.hasPrefix "FAILURE:" message then
              "failed"
            else if lib.hasPrefix "WARNING:" message then
              "warn"
            else
              null;

          pushoverPriorityOverride =
            if lib.hasPrefix "INFO:" message && lib.hasSuffix "skipping upgrade" message then
              -1
            else if lib.hasPrefix "INFO:" message && lib.hasInfix "Borg backup" message then
              -1
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
            else if lib.hasPrefix "INFO:" message && lib.hasInfix "Borg backup" message then
              lib.removePrefix "INFO: " message
            else if lib.hasPrefix "FAILURE:" message then
              lib.removePrefix "FAILURE: " message
            else if lib.hasPrefix "WARNING:" message then
              lib.removePrefix "WARNING: " message
            else
              message;
        in
        ''
          ${lib.optionalString shouldSendUserNotify ''${pkgs.util-linux}/bin/logger -p user.${level} -t nx-user-notify "${userNotifyMessage}"''}
          ${lib.optionalString shouldSendPushover ''pushover-send --title "Auto-Upgrade" --message "${pushoverMessage}" --type ${pushoverType} ${
            if pushoverPriorityOverride != null then
              "--priority ${builtins.toString pushoverPriorityOverride}"
            else
              ""
          } || true''}
          echo "${message}" ${if level == "err" then ">&2" else ""}
        '';

      checkBorgRunningScript = ''
        check_borg_running() {
          if ${pkgs.systemd}/bin/systemctl is-active --quiet borgbackup-job-system.service; then
            ${logScript "info" "INFO: Borg backup is currently running, delaying auto-upgrade"}
            exit 0
          fi
        }
      '';

      checkDailyStartScript = ''
        check_daily_start() {
          if [[ ! -f "/tmp/nx-force-upgrade" ]]; then
            TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
            if ${pkgs.systemd}/bin/journalctl -u nx-auto-upgrade.service --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" -q --grep="Starting NX Auto-Upgrade" >/dev/null 2>&1; then
              exit 0
            fi
          fi
          ${pkgs.coreutils}/bin/rm -f /tmp/nx-force-upgrade
        }
      '';

      checkDailyStartNotifyScript = ''
        check_daily_start_notify() {
          if [[ ! -f "/tmp/nx-force-upgrade" ]]; then
            TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
            if ${pkgs.systemd}/bin/journalctl -u nx-auto-upgrade.service --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" -q --grep="Starting NX Auto-Upgrade" >/dev/null 2>&1; then
              exit 0
            fi
          fi
        }
      '';

      signatureVerificationScript = lib.optionalString self.settings.verifySignatures ''
        setup_verification_keyring() {
          local keyring_dir=$(${pkgs.coreutils}/bin/mktemp -d -t nx-auto-upgrade-keyring-XXXXXX)
          cleanup_paths+=("$keyring_dir")

          ${pkgs.coreutils}/bin/chown ${self.host.mainUser.username}:${
            config.users.users.${self.host.mainUser.username}.group
          } "$keyring_dir"
          ${pkgs.coreutils}/bin/chmod 700 "$keyring_dir"

          ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} GNUPGHOME="$keyring_dir" ${pkgs.gnupg}/bin/gpg --batch --import ${config.sops.secrets.auto-upgrade-main-signing-key.path} >/dev/null 2>&1
          ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} GNUPGHOME="$keyring_dir" ${pkgs.gnupg}/bin/gpg --batch --import ${config.sops.secrets.auto-upgrade-github-signing-key.path} >/dev/null 2>&1

          local main_key_id="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.auto-upgrade-main-key-id.path})"
          local github_key_id="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.auto-upgrade-github-key-id.path})"

          ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} GNUPGHOME="$keyring_dir" ${pkgs.gnupg}/bin/gpg --batch --command-fd 0 --edit-key "$main_key_id" <<< $'trust\n5\ny\nquit' >/dev/null 2>&1
          ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} GNUPGHOME="$keyring_dir" ${pkgs.gnupg}/bin/gpg --batch --command-fd 0 --edit-key "$github_key_id" <<< $'trust\n5\ny\nquit' >/dev/null 2>&1

          export GNUPGHOME="$keyring_dir"
          ${pkgs.coreutils}/bin/echo "Set up dedicated GPG keyring for signature verification"
        }

        verify_commit_signature() {
          local repo_path="$1"
          local repo_name="$2"
          local commit="$3"

          cd "$repo_path"

          if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} \
            GNUPGHOME="$GNUPGHOME" \
            ${gitEnv} \
            ${pkgs.git}/bin/git verify-commit "$commit" >/dev/null 2>&1; then
            ${logScript "err" "FAILURE: Commit $commit in $repo_name has no valid signature!"}
            return 1
          fi

          return 0
        }

        verify_new_commits() {
          local repo_path="$1"
          local repo_name="$2"
          local old_commit="$3"
          local new_commit="$4"

          cd "$repo_path"

          if [[ "$old_commit" == "$new_commit" ]]; then
            return 0
          fi

          local new_commits=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-list "$old_commit".."$new_commit")
          local commit_count=$(echo "$new_commits" | ${pkgs.coreutils}/bin/wc -l)

          for commit in $new_commits; do
            if ! verify_commit_signature "$repo_path" "$repo_name" "$commit"; then
              return 1
            fi
          done

          ${pkgs.coreutils}/bin/echo "All new commit signatures verified successfully in $repo_name"
          return 0
        }
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
              ${logScript "err" "FAILURE: Network connectivity to $host failed after $max_retries attempts!"}
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
            ${logScript "err" "FAILURE: Repository $repo_name not found at $repo_path!"}
            exit 1
          fi

          if [[ ! -d "$repo_path/.git" ]]; then
            ${logScript "err" "FAILURE: Directory $repo_path is not a git repository!"}
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
            ${logScript "err" "WARNING: Repository $repo_name has uncommitted changes!"}
            exit 2
          fi
        }

        check_git_clean "${nxcoreDir}" "nxcore"
        check_git_clean "${nxconfigDir}" "nxconfig"
      '';

      setupRemotesScript = ''
                setup_nx_auto_upgrade_remote() {
                  local repo_path="$1"
                  local repo_name="$2"
                  local iso_url="$3"

                  cd "$repo_path"

                  if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git remote get-url nx-auto-upgrade >/dev/null 2>&1; then
                    ${logScript "info" "INFO: Adding nx-auto-upgrade remote for $repo_name"}

                    local token=$(cat ${config.sops.secrets.nx-github-access-token.path})
                    local auth_url="https://token:$token@''${iso_url#https://}"

                    ${pkgs.coreutils}/bin/cat >> .git/config << EOF

        [remote "nx-auto-upgrade"]
        	url = $auth_url
        	fetch = +refs/heads/*:refs/remotes/nx-auto-upgrade/*
        EOF
                    ${pkgs.coreutils}/bin/chown ${self.host.mainUser.username}:${
                      config.users.users.${self.host.mainUser.username}.group
                    } .git/config
                  fi
                }

                setup_nx_auto_upgrade_remote "${nxcoreDir}" "nxcore" "${self.variables.coreRepoIsoUrl}"
                setup_nx_auto_upgrade_remote "${nxconfigDir}" "nxconfig" "${self.variables.configRepoIsoUrl}"
      '';

      checkForChangesScript = ''
        check_for_changes() {
          local repo_path="$1"
          local repo_name="$2"

          cd "$repo_path"

          if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git fetch nx-auto-upgrade >/dev/null 2>&1; then
            ${logScript "err" "FAILURE: Failed to fetch $repo_name repository!"}
            exit 1
          fi

          local local_commit=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse HEAD)
          local remote_commit=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse nx-auto-upgrade/main)

          if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git merge-base --is-ancestor "$local_commit" nx-auto-upgrade/main >/dev/null 2>&1; then
            ${logScript "err" "WARNING: Repository $repo_name local commit is ahead of remote!"}
            exit 2
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

          local old_commit=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse HEAD)

          ${logScript "info" "INFO: ${
            if self.settings.dryRun then "Would pull" else "Pulling"
          } latest changes for $repo_name"}

          ${
            if self.settings.dryRun then
              ''
                ${pkgs.coreutils}/bin/echo "Would execute: git pull from nx-auto-upgrade remote"
              ''
            else
              ''
                if ! ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git pull nx-auto-upgrade main; then
                  ${logScript "err" "FAILURE: Failed to pull $repo_name repository!"}
                  exit 1
                fi

                ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git update-ref refs/remotes/origin/main refs/remotes/nx-auto-upgrade/main

                ${pkgs.coreutils}/bin/chown -R ${self.host.mainUser.username}:${
                  config.users.users.${self.host.mainUser.username}.group
                } "$repo_path"

                ${lib.optionalString self.settings.verifySignatures ''
                  local new_commit=$(${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse HEAD)
                  if ! verify_new_commits "$repo_path" "$repo_name" "$old_commit" "$new_commit"; then
                    ${logScript "err" "FAILURE: Signature verification failed for $repo_name!"}
                    exit 1
                  fi
                ''}
              ''
          }
        }

        cd "${nxcoreDir}"
        OLD_REBOOT_MARKER=$(${pkgs.coreutils}/bin/cat .nx-auto-upgrade-reboot-required 2>/dev/null || echo "")

        pull_repo "${nxcoreDir}" "nxcore"
        pull_repo "${nxconfigDir}" "nxconfig"

        cd "${nxcoreDir}"
        FORCE_REBOOT=false
        if [[ -f ".nx-auto-upgrade-reboot-required" ]]; then
          NEW_REBOOT_MARKER=$(${pkgs.coreutils}/bin/cat .nx-auto-upgrade-reboot-required 2>/dev/null || echo "")
          if [[ -n "$NEW_REBOOT_MARKER" && "$OLD_REBOOT_MARKER" != "$NEW_REBOOT_MARKER" ]]; then
            CURRENT_FLAKE_HASH=$(${pkgs.coreutils}/bin/sha256sum flake.lock | ${pkgs.coreutils}/bin/cut -d' ' -f1)
            if [[ "$CURRENT_FLAKE_HASH" == "$NEW_REBOOT_MARKER" ]]; then
              ${logScript "info" "INFO: Remote changes indicate reboot required for current flake.lock state"}
              FORCE_REBOOT=true
            fi
          fi
        fi
      '';

      setupGitSafeDirectoriesScript = ''
        setup_git_safe_directories() {
          if ! ${pkgs.git}/bin/git config --global --get-all safe.directory | ${pkgs.gnugrep}/bin/grep -q "^${nxcoreDir}$"; then
            ${pkgs.git}/bin/git config --global --add safe.directory "${nxcoreDir}"
            ${logScript "info" "INFO: Added ${nxcoreDir} to git safe directories"}
          fi

          if ! ${pkgs.git}/bin/git config --global --get-all safe.directory | ${pkgs.gnugrep}/bin/grep -q "^${nxconfigDir}$"; then
            ${pkgs.git}/bin/git config --global --add safe.directory "${nxconfigDir}"
            ${logScript "info" "INFO: Added ${nxconfigDir} to git safe directories"}
          fi
        }
      '';

      upgradeScript = ''
        ${logScript "info" "INFO: ${
          if self.settings.dryRun then "Would start" else "Starting"
        } system rebuild"}
        cd "${nxcoreDir}"

        PROFILE_PATH="${nxconfigDir}/profiles/nixos/${self.host.profileName}"

        export NIXOS_LABEL="auto-$(${pkgs.coreutils}/bin/date +%d%m.%H%M)"

        ${
          if self.settings.dryRun then
            ''
              REBUILD_ACTION="switch"
              ${lib.optionalString self.settings.allowReboot ''
                if [[ "$FORCE_REBOOT" == "true" ]]; then
                  REBUILD_ACTION="boot"
                fi
              ''}
              ${pkgs.coreutils}/bin/echo "Would execute: nixos-rebuild $REBUILD_ACTION --flake '.#${profileName}' --impure --override-input config 'path:${nxconfigDir}' --override-input profile 'path:$PROFILE_PATH' --print-build-logs"
              ${logScript "info" "System rebuild command prepared"}
            ''
          else
            ''
              REBUILD_ACTION="switch"
              ${lib.optionalString self.settings.allowReboot ''
                if [[ "$FORCE_REBOOT" == "true" ]]; then
                  REBUILD_ACTION="boot"
                  ${logScript "info" "INFO: Using boot action since reboot is required"}
                fi
              ''}

              if ! ${pkgs.nixos-rebuild}/bin/nixos-rebuild $REBUILD_ACTION \
                --flake ".#${profileName}" \
                --impure \
                --no-update-lock-file \
                --override-input config "path:${nxconfigDir}" \
                --override-input profile "path:$PROFILE_PATH" \
                --print-build-logs \
                --show-trace; then
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
            if ( [[ "''${current_time}" > "''${lower}" ]] || [[ "''${current_time}" == "''${lower}" ]] ) && [[ "''${current_time}" < "''${upper}" ]]; then
              return 0
            fi
          else
            if [[ "''${current_time}" < "''${upper}" ]] || [[ "''${current_time}" > "''${lower}" ]] || [[ "''${current_time}" == "''${lower}" ]]; then
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

        ${logScript "info" "INFO: Checking if reboot is needed"}
        if [[ "$FORCE_REBOOT" == "true" ]] || check_reboot_needed; then
          ${
            if self.settings.rebootWindow != null then
              ''
                if check_reboot_window; then
                  if ${pkgs.systemd}/bin/systemctl is-active --quiet borgbackup-job-system.service; then
                    ${logScript "info" "SUCCESS-REBOOT-LATER: Reboot needed and within window but borg backup is running - scheduling reboot in window (${self.settings.rebootWindow.lower}-${self.settings.rebootWindow.upper})"}
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
                  else
                    ${logScript "info" "SUCCESS-REBOOT-NOW: Reboot needed and within window - ${
                      if self.settings.dryRun then "would reboot" else "rebooting"
                    } in +1 minute"}
                    ${
                      if self.settings.dryRun then
                        ''${pkgs.coreutils}/bin/echo "Would execute: shutdown -r +1 --no-wall"''
                      else
                        ''${config.systemd.package}/bin/shutdown -r +1 --no-wall''
                    }
                  fi
                else
                  ${logScript "info" "SUCCESS-REBOOT-LATER: Reboot needed and scheduled in window (${self.settings.rebootWindow.lower}-${self.settings.rebootWindow.upper})"}
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
                if ${pkgs.systemd}/bin/systemctl is-active --quiet borgbackup-job-system.service; then
                  ${logScript "info" "SUCCESS-REBOOT-LATER: Reboot needed but borg backup is running - scheduling reboot"}
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
                else
                  ${logScript "info" "SUCCESS-REBOOT-NOW: Reboot needed - ${
                    if self.settings.dryRun then "would reboot" else "rebooting"
                  } in +1 minute"}
                  ${
                    if self.settings.dryRun then
                      ''${pkgs.coreutils}/bin/echo "Would execute: shutdown -r +1 --no-wall"''
                    else
                      ''${config.systemd.package}/bin/shutdown -r +1 --no-wall''
                  }
                fi
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

        if ${pkgs.systemd}/bin/systemctl is-active --quiet borgbackup-job-system.service; then
          ${logScript "info" "INFO: Borg backup is currently running, skipping reboot iteration"}
          exit 0
        fi

        ${
          if self.settings.dryRun then
            ''
              ${logScript "info" "Would check reboot marker and reboot if in window"}
              ${pkgs.coreutils}/bin/echo "Would check marker file: $reboot_marker"
              ${pkgs.coreutils}/bin/echo "Would execute: shutdown -r now --no-wall"
            ''
          else if self.settings.rebootWindow != null then
            ''
              if check_reboot_window; then
                ${logScript "info" "INFO: Delayed reboot marker found and inside reboot window, rebooting now"}
                ${config.systemd.package}/bin/shutdown -r now --no-wall
              fi
            ''
          else
            ''
              ${logScript "info" "INFO: Delayed reboot marker found, rebooting now"}
              ${config.systemd.package}/bin/shutdown -r now --no-wall
            ''
        }
      '';

    in
    {
      sops.secrets.nx-github-access-token = {
        sopsFile = self.config.secretsPath "global-secrets.yaml";
        mode = "0440";
        owner = "root";
        group = config.users.users.${self.host.mainUser.username}.group;
      };

      sops.secrets.auto-upgrade-main-signing-key = lib.mkIf self.settings.verifySignatures {
        sopsFile = self.config.secretsPath "auto-upgrade-signing-keys.yaml";
        mode = "0440";
        owner = "root";
        group = config.users.users.${self.host.mainUser.username}.group;
      };

      sops.secrets.auto-upgrade-main-key-id = lib.mkIf self.settings.verifySignatures {
        sopsFile = self.config.secretsPath "auto-upgrade-signing-keys.yaml";
        mode = "0440";
        owner = "root";
        group = config.users.users.${self.host.mainUser.username}.group;
      };

      sops.secrets.auto-upgrade-github-signing-key = lib.mkIf self.settings.verifySignatures {
        sopsFile = self.config.secretsPath "auto-upgrade-signing-keys.yaml";
        mode = "0440";
        owner = "root";
        group = config.users.users.${self.host.mainUser.username}.group;
      };

      sops.secrets.auto-upgrade-github-key-id = lib.mkIf self.settings.verifySignatures {
        sopsFile = self.config.secretsPath "auto-upgrade-signing-keys.yaml";
        mode = "0440";
        owner = "root";
        group = config.users.users.${self.host.mainUser.username}.group;
      };

      systemd.services.nx-auto-upgrade-log-failure = {
        description = "Log NX Auto-Upgrade Failure";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        path =
          lib.optionals (self.isModuleEnabled "notifications.pushover" && self.settings.pushoverNotifications)
            [
              (self.importFileFromOtherModuleSameInput {
                inherit args self;
                modulePath = "notifications.pushover";
              }).custom.pushoverSendScript
            ];
        script = logScript "err" "FAILURE: Auto-upgrade failed!";
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

        path =
          lib.optionals (self.isModuleEnabled "notifications.pushover" && self.settings.pushoverNotifications)
            [
              (self.importFileFromOtherModuleSameInput {
                inherit args self;
                modulePath = "notifications.pushover";
              }).custom.pushoverSendScript
            ];

        script = ''
          ${checkDailyStartNotifyScript}
          check_daily_start_notify
          ${logScript "info" "NOTICE: Auto-upgrade starting in ${builtins.toString self.settings.preNotificationTimeMinutes}M - avoid repository changes"}
        '';
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
          SuccessExitStatus = [
            0
            2
          ];
          ExecStopPost = "${pkgs.writeShellScript "nx-auto-upgrade-stop-handler" ''
            if [ "$EXIT_CODE" = "killed" ]; then
              ${logScript "err" "FAILURE: Auto-upgrade was stopped/interrupted!"}
            fi
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
            gnugrep
            openssh
            config.nix.package.out
            nixos-rebuild
            sudo
            util-linux
            iputils
            gnutar
            xz
          ]
          ++ lib.optionals self.settings.verifySignatures [
            gnupg
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

            lock_dir="/tmp/.nx-deployment-lock"
            cleanup_paths=("$lock_dir")

            if [[ -d "$lock_dir" ]]; then
              ${logScript "err" "FAILURE: Another deployment is already running!"}
              exit 1
            fi

            if ! ${pkgs.coreutils}/bin/mkdir "$lock_dir" 2>/dev/null; then
              ${logScript "err" "FAILURE: Failed to create deployment lock!"}
              exit 1
            fi

            cleanup() {
              for path in "''${cleanup_paths[@]}"; do
                ${pkgs.coreutils}/bin/rm -rf "$path" 2>/dev/null || true
              done
            }
            trap cleanup EXIT TERM

            ${checkDailyStartScript}
            check_daily_start

            ${logScript "info" "STARTED: Auto-upgrade beginning"}
            ${pkgs.coreutils}/bin/sleep 5

            ${checkBorgRunningScript}
            check_borg_running

            ${setupGitSafeDirectoriesScript}
            setup_git_safe_directories

            ${checkNetworkScript}
            ${checkRepositoriesExistScript}
            ${setupRemotesScript}
            ${checkGitWorktreesScript}

            ${signatureVerificationScript}
            ${lib.optionalString self.settings.verifySignatures ''
              setup_verification_keyring

              verify_commit_signature "${nxcoreDir}" "nxcore" "$(cd ${nxcoreDir} && ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse HEAD)"
              verify_commit_signature "${nxconfigDir}" "nxconfig" "$(cd ${nxconfigDir} && ${pkgs.sudo}/bin/sudo -u ${self.host.mainUser.username} ${gitEnv} ${pkgs.git}/bin/git rev-parse HEAD)"
            ''}

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

        path =
          with pkgs;
          [
            coreutils
            util-linux
            config.systemd.package
          ]
          ++
            lib.optionals (self.isModuleEnabled "notifications.pushover" && self.settings.pushoverNotifications)
              [
                (self.importFileFromOtherModuleSameInput {
                  inherit args self;
                  modulePath = "notifications.pushover";
                }).custom.pushoverSendScript
              ];

        script = delayedRebootScript;
        after = [ "multi-user.target" ];
      };

      systemd.timers.nx-auto-upgrade-reboot-checker = lib.mkIf self.settings.allowReboot {
        description = "NX Auto-Upgrade Delayed Reboot Checker Timer";
        timerConfig = {
          OnCalendar = "*:0/15";
          OnStartupSec = "15min";
          Persistent = true;
        };
        wantedBy = [ "timers.target" ];
      };

      system.autoUpgrade.enable = lib.mkForce false;

      environment.persistence."${self.persist}" = {
        files = [
          "/root/.gitconfig"
        ];
      };
    };
}
