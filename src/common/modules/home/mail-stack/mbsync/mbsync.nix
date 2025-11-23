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
            channel = {
              CopyArrivalDate = "yes";
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
          ExecStartPre = pkgs.writeShellScript "mbsync-prep-maildir" ''
            #!/usr/bin/env bash
            set -euo pipefail

            ${lib.concatMapStringsSep "\n" (accountKey: ''
              ${pkgs.coreutils}/bin/mkdir -p "${mailDir}/${accountKey}"
            '') (lib.attrNames accountsConfig.accounts)}
          '';
          ExecStart = pkgs.writeShellScript "mbsync-sync" ''
            #!/usr/bin/env bash
            set -euo pipefail
            EXIT_CODE=0

            echo "Starting mbsync..."
            if ! ${pkgs.isync}/bin/mbsync -a; then
              EXIT_CODE=$?
              echo "mbsync encountered an error (exit code: $EXIT_CODE)"
            fi

            ${
              if (self.isModuleEnabled "mail-stack.notmuch") then
                ''
                  echo "Updating Notmuch database..."
                  if ! ${pkgs.notmuch}/bin/notmuch new; then
                    EXIT_CODE=$?
                    echo "Notmuch encountered an error (exit code: $EXIT_CODE)"
                  fi
                ''
              else
                ""
            }

            if [ $EXIT_CODE -ne 0 ]; then
              exit 1
            else
              echo "Mail sync completed without errors."
              exit 0
            fi
          '';
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

          SYNC_START=$(date '+%Y-%m-%d %H:%M:%S')

          echo "Triggering manual mail sync..."
          echo "Monitoring sync progress..."
          echo

          journalctl --user -u mbsync.service -f --since "$SYNC_START" --no-pager &
          JOURNAL_PID=$!

          cleanup() {
            kill $JOURNAL_PID 2>/dev/null || true
          }
          trap cleanup EXIT INT TERM

          sleep 1
          systemctl --user start mbsync.service &
          sleep 1

          if timeout 120s bash -c 'while [[ "$(systemctl --user is-active mbsync.service)" =~ ^(activating|active)$ ]]; do sleep 0.5; done'; then
            sleep 1
            echo
            echo "=== Final Status ==="

            if systemctl --user is-failed mbsync.service >/dev/null 2>&1; then
              echo "Mail sync failed!"
              exit 1
            else
              echo "Mail sync completed successfully."
              exit 0
            fi
          else
            echo
            echo "Mail sync is taking longer than expected!"
            echo "Current status:"
            systemctl --user --no-pager status mbsync.service --lines=10 || true
            exit 2
          fi
        '')
      ];
    };
}
