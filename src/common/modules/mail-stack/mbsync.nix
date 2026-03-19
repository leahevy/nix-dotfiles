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
    withNotifications = true;
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

            BLUE='\033[0;34m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            RED='\033[0;31m'
            RESET='\033[0m'

            RUNTIME_DIR="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}/runtime-$(id -u)}"
            LOCKDIR="$RUNTIME_DIR/process-mails.lock"

            mkdir -p "$RUNTIME_DIR"

            if ! mkdir "$LOCKDIR" 2>/dev/null; then
              echo -e "''${YELLOW}⚠️ Another mail processing instance is already running. Exiting.''${RESET}"
              exit 0
            fi

            cleanup() {
              rmdir "$LOCKDIR" 2>/dev/null || true
            }
            trap cleanup EXIT INT TERM

            ${
              if (self.isModuleEnabled "mail-stack.notmuch") then
                ''
                  echo -e "''${BLUE}🔄 Processing existing mail before sync...''${RESET}"
                  if [ -x "${config.home.homeDirectory}/.local/bin/scripts/notmuch-process-mails.sh" ]; then
                    if ! ${config.home.homeDirectory}/.local/bin/scripts/notmuch-process-mails.sh --move-first --no-lock-check; then
                      EXIT_CODE=$?
                      echo -e "''${RED}❌ Mail processing encountered an error (exit code: $EXIT_CODE)''${RESET}"
                    fi
                  fi
                ''
              else
                ""
            }

            check_connectivity() {
              local host="$1"
              local max_retries=5
              local retry=0
              local wait_time=1

              echo -e "''${YELLOW}🌐 Checking connectivity to $host...''${RESET}"
              while [ $retry -lt $max_retries ]; do
                if ${pkgs.iputils}/bin/ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
                  echo -e "''${GREEN}✅ Connectivity to $host confirmed.''${RESET}"
                  return 0
                fi

                retry=$((retry + 1))
                if [ $retry -lt $max_retries ]; then
                  echo -e "''${YELLOW}⚠️  Connectivity check failed (attempt $retry/$max_retries). Waiting $wait_time seconds...''${RESET}"
                  sleep $wait_time
                  wait_time=$((wait_time * 2))
                fi
              done

              echo -e "''${RED}❌ Failed to reach $host after $max_retries attempts.''${RESET}"
              return 1
            }

            ${
              let
                primaryAccountKey = lib.findFirst (
                  name: accountsConfig.accounts.${name}.default or false
                ) (lib.head (lib.attrNames accountsConfig.accounts)) (lib.attrNames accountsConfig.accounts);
                buildServerConfig =
                  (self.importFileFromOtherModuleSameInput {
                    inherit args self;
                    modulePath = "mail-stack.accounts";
                  }).custom.buildServerConfig;
                primaryAccount = accountsConfig.accounts.${primaryAccountKey};
                serverConfig = buildServerConfig primaryAccountKey primaryAccount;
              in
              ''
                if ! check_connectivity "${serverConfig.imap.host}"; then
                  echo -e "''${RED}❌ Cannot reach mail server. Aborting sync.''${RESET}"
                  exit 1
                fi
              ''
            }

            echo -e "''${BLUE}📨 Starting mbsync...''${RESET}"
            if ! ${pkgs.isync}/bin/mbsync -a; then
              EXIT_CODE=$?
              echo -e "''${RED}❌ mbsync encountered an error (exit code: $EXIT_CODE)''${RESET}"
            fi

            ${
              if (self.isModuleEnabled "mail-stack.notmuch") then
                ''
                  ${
                    if self.settings.withNotifications then
                      ''
                        BEFORE_COUNT=$(${pkgs.notmuch}/bin/notmuch count -- tag:inbox)
                      ''
                    else
                      ""
                  }

                  echo -e "''${BLUE}🔍 Processing mail with Notmuch and afew...''${RESET}"
                  if ! ~/.local/bin/scripts/notmuch-process-mails.sh --no-lock-check; then
                    EXIT_CODE=$?
                    echo -e "''${RED}❌ Notmuch processing encountered an error (exit code: $EXIT_CODE)''${RESET}"
                  fi

                  ${
                    if self.settings.withNotifications then
                      ''
                        AFTER_COUNT=$(${pkgs.notmuch}/bin/notmuch count -- tag:inbox)
                        NEW_COUNT=$((AFTER_COUNT - BEFORE_COUNT))
                        if [ "$NEW_COUNT" -gt 0 ]; then
                          ${pkgs.libnotify}/bin/notify-send "New Mail" "$NEW_COUNT new messages" --icon=email
                        elif [ "$NEW_COUNT" -lt 0 ]; then
                          ${pkgs.libnotify}/bin/notify-send "Mail Update" "Some messages in inbox were updated" --icon=email
                        fi
                      ''
                    else
                      ""
                  }
                ''
              else
                ""
            }

            if [ $EXIT_CODE -ne 0 ]; then
              exit 1
            else
              echo -e "''${GREEN}✅ Mail sync completed without errors.''${RESET}"
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

          BLUE='\033[0;34m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          RED='\033[0;31m'
          RESET='\033[0m'

          SYNC_START=$(date '+%Y-%m-%d %H:%M:%S')

          echo -e "''${BLUE}📨 Triggering manual mail sync...''${RESET}"
          echo -e "''${YELLOW}👁️  Monitoring sync progress...''${RESET}"
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
            echo -e "''${BLUE}=== Final Status ===''${RESET}"

            if systemctl --user is-failed mbsync.service >/dev/null 2>&1; then
              echo -e "''${RED}❌ Mail sync failed!''${RESET}"
              exit 1
            else
              echo -e "''${GREEN}✅ Mail sync completed successfully.''${RESET}"
              exit 0
            fi
          else
            echo
            echo -e "''${YELLOW}⏱️  Mail sync is taking longer than expected!''${RESET}"
            echo -e "''${YELLOW}📊 Current status:''${RESET}"
            systemctl --user --no-pager status mbsync.service --lines=10 || true
            exit 2
          fi
        '')
      ];
    };
}
