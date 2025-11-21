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
  name = "mbsync";
  group = "mail-stack";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      mail-stack = {
        accounts = true;
      };
    };
  };

  settings = {
    syncInterval = "5min";
    enableBackgroundSync = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
      accountsConfig = self.getModuleConfig "mail-stack.accounts";
      baseDataDir = "${config.xdg.dataHome}/${accountsConfig.baseDataDir}";
      mailDir = "${baseDataDir}/${accountsConfig.maildirPath}";

    in
    {
      accounts.email.accounts = lib.mapAttrs (accountKey: _: {
        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          patterns = [ "*" ];
          subFolders = "Verbatim";
          extraConfig = {
            account = {
              PipelineDepth = 50;
              Timeout = 120;
            };
          };
        };
      }) accountsConfig.accounts;

      programs.mbsync.enable = true;

      systemd.user.services.mbsync = {
        Unit = {
          Description = "Mailbox synchronization";
          StartLimitIntervalSec = 300;
          StartLimitBurst = 3;
        };
        Service = {
          Type = "oneshot";
          ExecStartPre = "+${pkgs.coreutils}/bin/mkdir -p %h/${lib.removePrefix "${config.home.homeDirectory}/" mailDir}";
          ExecStart = "${pkgs.isync}/bin/mbsync -a";
          Restart = "on-failure";
          RestartSec = 60;
        };
      };

      systemd.user.timers.mbsync = lib.mkIf self.settings.enableBackgroundSync {
        Unit.Description = "Mailbox synchronization timer";
        Timer = {
          OnBootSec = "2m";
          OnUnitActiveSec = self.settings.syncInterval;
          Persistent = true;
          Unit = "mbsync.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      home.packages = [
        (pkgs.writeShellScriptBin "mbsync-fetch-mail" ''
          #!/usr/bin/env bash
          set -euo pipefail

          echo "Triggering manual mail sync..."
          systemctl --user start mbsync.service

          echo "Waiting for sync to complete..."
          systemctl --user --no-pager status mbsync.service --lines=5

          if systemctl --user is-active mbsync.service >/dev/null 2>&1; then
            echo "Mail sync is running..."
            echo
            if timeout 120s bash -c 'while systemctl --user is-active mbsync.service >/dev/null 2>&1; do sleep 1; done'; then
              echo "Mail sync completed successfully."
              exit 0
            else
              echo "Mail sync is taking longer than expected!"
              exit 2
            fi
          else
            if systemctl --user is-failed mbsync.service >/dev/null 2>&1; then
              echo "Mail sync failed!"
              echo
              systemctl --user --no-pager status mbsync.service --lines=10
              exit 1
            else
              echo "Mail sync completed successfully."
              exit 0
            fi
          fi
        '')
      ];
    };
}
