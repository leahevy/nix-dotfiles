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
  name = "borg-backup";

  group = "storage";
  input = "linux";
  namespace = "system";

  settings = {
    repository = {
      server = "";
      port = 22;
      user = "root";
      path = "";
    };

    schedule = "*-*-* 15:43:10";
    waitForNetwork = true;
    pingTarget = null;
    maxNetworkRetries = 30;

    compression = "auto,zstd";

    prune = {
      keep = {
        within = "1d";
        daily = 7;
        weekly = 4;
        monthly = -1;
      };
    };

    withData = false;
    dataPath = "/data";

    excludes = {
      persist = [ ".snapshots" ];
      nix = [ ];
      boot = [ ];
      data = [ ".snapshots" ];
    };

    pushoverNotifications = true;
  };

  assertions = [
    {
      assertion = self.settings.repository.server != "";
      message = "borg-backup: repository.server must be configured";
    }
    {
      assertion = self.settings.repository.path != "";
      message = "borg-backup: repository.path must be configured";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      repoUrl = "ssh://${self.settings.repository.user}@${self.settings.repository.server}:${toString self.settings.repository.port}${self.settings.repository.path}";

      pingTarget =
        if self.settings.pingTarget != null then
          self.settings.pingTarget
        else
          self.settings.repository.server;

      networkWaitScript = lib.optionalString self.settings.waitForNetwork ''
        ${pkgs.coreutils}/bin/echo "Waiting for network connectivity..."
        retries=0
        max_retries=${toString self.settings.maxNetworkRetries}
        until ${pkgs.iputils}/bin/ping -c1 -q ${pingTarget} >/dev/null 2>&1; do
          retries=$((retries + 1))
          if [ $retries -ge $max_retries ]; then
            ${pkgs.coreutils}/bin/echo "Network connectivity failed after $max_retries attempts"
            exit 1
          fi
          ${pkgs.coreutils}/bin/echo "Network not ready, waiting 30s... (attempt $retries/$max_retries)"
          ${pkgs.coreutils}/bin/sleep 30
        done
        ${pkgs.coreutils}/bin/echo "Network connectivity confirmed"
      '';

      cleanupSnapshotScript =
        {
          snapshotName,
          snapshotDir,
          canFail ? false,
        }:
        ''
          if ${pkgs.btrfs-progs}/bin/btrfs subvolume show ${snapshotDir}/${snapshotName} 2>/dev/null; then
            ${pkgs.coreutils}/bin/echo "Cleaning up ${snapshotName} backup snapshot..."
            ${pkgs.btrfs-progs}/bin/btrfs subvolume delete ${snapshotDir}/${snapshotName} ${
              if canFail then "|| true" else ""
            };
          fi
        '';

      createSnapshotScript =
        {
          volume,
          snapshotName,
          snapshotDir,
        }:
        ''
          ${pkgs.coreutils}/bin/mkdir -p ${snapshotDir}
          ${cleanupSnapshotScript { inherit snapshotName snapshotDir; }}
          ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r ${volume} ${snapshotDir}/${snapshotName}
        '';

      checkAutoUpgradeRunningScript = ''
        check_auto_upgrade_running() {
          if ${pkgs.systemd}/bin/systemctl is-active --quiet nx-auto-upgrade.service; then
            ${logScript "info" "INFO: Auto-upgrade is currently running, skipping backup"}
            exit 0
          fi
        }
      '';

      checkDailyBackupCompleteScript = ''
        check_daily_backup_complete() {
          TODAY=$(${pkgs.coreutils}/bin/date +%Y-%m-%d)
          if ${pkgs.systemd}/bin/journalctl -u borgbackup-job-system.service --since="$TODAY 00:00:00" --until="$TODAY 23:59:59" -q --grep="SUCCESS: System backup completed successfully" >/dev/null 2>&1; then
            exit 0
          fi
        }
      '';

      logScript =
        level: message:
        let
          userNotifyEnabled = (self.user.isModuleEnabled "notifications.user-notify");
          pushoverEnabled =
            (self.isModuleEnabled "notifications.pushover") && self.settings.pushoverNotifications;

          userNotifyMessage =
            if userNotifyEnabled then
              if lib.hasPrefix "STARTED:" message then
                "Borg Backup (starting)|folder-sync: ${lib.removePrefix "STARTED: " message}"
              else if lib.hasPrefix "SUCCESS:" message then
                "Borg Backup (completed)|checkmark: ${lib.removePrefix "SUCCESS: " message}"
              else if lib.hasPrefix "FAILURE:" message then
                "Borg Backup (failed)|dialog-error: ${lib.removePrefix "FAILURE: " message}"
              else if lib.hasPrefix "INFO:" message then
                "Borg Backup (info)|folder-sync: ${lib.removePrefix "INFO: " message}"
              else
                "Borg Backup|folder-sync: ${message}"
            else
              "";

          pushoverType =
            if lib.hasPrefix "STARTED:" message then
              "started"
            else if lib.hasPrefix "SUCCESS:" message then
              "success"
            else if lib.hasPrefix "FAILURE:" message then
              "failed"
            else if lib.hasPrefix "INFO:" message && lib.hasInfix "Auto-upgrade" message then
              "info"
            else
              null;

          shouldSendPushover = pushoverEnabled && pushoverType != null;

          pushoverMessage =
            if lib.hasPrefix "STARTED:" message then
              lib.removePrefix "STARTED: " message
            else if lib.hasPrefix "SUCCESS:" message then
              lib.removePrefix "SUCCESS: " message
            else if lib.hasPrefix "FAILURE:" message then
              lib.removePrefix "FAILURE: " message
            else if lib.hasPrefix "INFO:" message && lib.hasInfix "Auto-upgrade" message then
              lib.removePrefix "INFO: " message
            else
              message;
        in
        ''
          ${lib.optionalString userNotifyEnabled ''${pkgs.util-linux}/bin/logger -p user.${level} -t nx-user-notify "${userNotifyMessage}"''}
          ${lib.optionalString shouldSendPushover ''${
            (self.importFileFromOtherModuleSameInput {
              inherit args self;
              modulePath = "notifications.pushover";
            }).custom.pushoverSendScript
          }/bin/pushover-send --title "Borg-Backup" --message "${pushoverMessage}" --type ${pushoverType} || true''}
          echo "${message}" ${if level == "err" then ">&2" else ""}
        '';

      backupPaths = [
        "/persist/.snapshots/persist"
        "/persist/.snapshots/nix"
        "/boot"
      ]
      ++ lib.optional self.settings.withData "${self.settings.dataPath}/.snapshots/data";

      allExcludes =
        (map (exclude: "/persist/.snapshots/persist/${exclude}") self.settings.excludes.persist)
        ++ (map (exclude: "/persist/.snapshots/nix/${exclude}") self.settings.excludes.nix)
        ++ (map (exclude: "/boot/${exclude}") self.settings.excludes.boot)
        ++ lib.optionals self.settings.withData (
          map (exclude: "${self.settings.dataPath}/.snapshots/data/${exclude}") self.settings.excludes.data
        );

    in
    {
      environment.systemPackages = [
        pkgs.borgbackup
        pkgs.btrfs-progs
      ];

      sops.secrets."${self.host.hostname}-borg-ssh-key" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "borg.ssh-key";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      sops.secrets."${self.host.hostname}-borg-passphrase" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "borg.passphrase";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      sops.secrets."${self.host.hostname}-borg-known-hosts" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "borg.known-hosts";
        mode = "0644";
        owner = "root";
        group = "root";
      };

      services.borgbackup.jobs.system = {
        repo = repoUrl;
        compression = self.settings.compression;
        encryption = {
          mode = "repokey-blake2";
          passCommand = "cat ${config.sops.secrets."${self.host.hostname}-borg-passphrase".path}";
        };
        environment = {
          BORG_RSH = "ssh -i ${
            config.sops.secrets."${self.host.hostname}-borg-ssh-key".path
          } -o UserKnownHostsFile=${config.sops.secrets."${self.host.hostname}-borg-known-hosts".path}";
        };
        inhibitsSleep = true;
        startAt = self.settings.schedule;
        persistentTimer = true;
        user = "root";
        group = "root";

        doInit = true;
        prune.keep = self.settings.prune.keep;

        preHook = ''
          ${pkgs.coreutils}/bin/echo "Waiting 2 minutes for system readiness..."
          ${pkgs.coreutils}/bin/sleep 120
          ${checkDailyBackupCompleteScript}
          check_daily_backup_complete
          ${checkAutoUpgradeRunningScript}
          check_auto_upgrade_running
          ${networkWaitScript}
          ${logScript "info" "STARTED: System backup starting"}
          ${createSnapshotScript {
            volume = "/persist";
            snapshotName = "persist";
            snapshotDir = "/persist/.snapshots";
          }}
          ${createSnapshotScript {
            volume = "/nix";
            snapshotName = "nix";
            snapshotDir = "/persist/.snapshots";
          }}
          ${lib.optionalString self.settings.withData (createSnapshotScript {
            volume = self.settings.dataPath;
            snapshotName = "data";
            snapshotDir = "${self.settings.dataPath}/.snapshots";
          })}
          ${logScript "info" "INFO: Snapshots created - starting backup..."}
        '';

        paths = backupPaths;
        exclude = allExcludes;

        postHook = ''
          ${cleanupSnapshotScript {
            snapshotName = "persist";
            snapshotDir = "/persist/.snapshots";
            canFail = true;
          }}
          ${cleanupSnapshotScript {
            snapshotName = "nix";
            snapshotDir = "/persist/.snapshots";
            canFail = true;
          }}
          ${lib.optionalString self.settings.withData (cleanupSnapshotScript {
            snapshotName = "data";
            snapshotDir = "${self.settings.dataPath}/.snapshots";
            canFail = true;
          })}
          ${logScript "info" "INFO: All snapshots deleted successfully"}
        '';

      };

      systemd.services.borg-backup-log-failure = {
        description = "Log Borg Backup Failure";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = logScript "err" "FAILURE: System backup failed - check journalctl -u borgbackup-job-system";
      };

      systemd.services.borg-backup-log-success = {
        description = "Log Borg Backup Success";
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
        script = ''
          if [ "$MONITOR_EXIT_CODE" = "exited" ]; then
            ${logScript "info" "SUCCESS: System backup completed successfully"}
          fi
        '';
      };

      systemd.services.borgbackup-job-system = {
        unitConfig = {
          OnFailure = "borg-backup-log-failure.service";
          OnSuccess = "borg-backup-log-success.service";
        };
        serviceConfig = {
          ReadWritePaths = [
            "/persist/.snapshots"
          ]
          ++ lib.optional self.settings.withData "${self.settings.dataPath}/.snapshots";

          ExecStopPost = "${pkgs.writeShellScript "borg-backup-stop-handler" ''
            if [ "$EXIT_CODE" = "killed" ]; then
              ${logScript "err" "FAILURE: System backup was stopped/interrupted"}
            fi
          ''}";
        };
      };

      environment.persistence."${self.persist}" = {
        directories = [
          "/root/.config/borg"
          "/root/.cache/borg"
        ];
      };

      system.activationScripts.borg-backup-setup = {
        text = ''
          ${pkgs.coreutils}/bin/mkdir -p /persist/.snapshots || true
          ${lib.optionalString self.settings.withData ''
            ${pkgs.coreutils}/bin/mkdir -p ${self.settings.dataPath}/.snapshots || true
          ''}
        '';
      };
    };
}
