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

  defaults = {
    repository = {
      server = "";
      port = 22;
      user = "root";
      path = "";
    };

    schedule = "*-*-* 16:43:10";
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

      logScript = level: message: ''
        ${pkgs.util-linux}/bin/logger -p user.${level} -t nx-borg-backup "${message}"
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
        startAt = self.settings.schedule;
        persistentTimer = true;
        user = "root";
        group = "root";

        doInit = true;
        prune.keep = self.settings.prune.keep;

        preHook = ''
          ${pkgs.coreutils}/bin/echo "Waiting 2 minutes for system readiness..."
          ${pkgs.coreutils}/bin/sleep 120
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
          ${logScript "info" "INFO: All snapshots created successfully"}
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
          ${logScript "info" "SUCCESS: System backup completed successfully"}
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

      systemd.services.borgbackup-job-system = {
        unitConfig.OnFailure = "borg-backup-log-failure.service";
        serviceConfig.ReadWritePaths = [
          "/persist/.snapshots"
        ]
        ++ lib.optional self.settings.withData "${self.settings.dataPath}/.snapshots";
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
