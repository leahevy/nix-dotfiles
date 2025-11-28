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
  name = "notmuch";
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
    maxAgeToProcess = 90;
    excludeTags = [ ];
    dkimFailAsSpam = false;

    virtualMailboxes = [
      # Example:
      # {
      #   name = "Action Required";
      #   query = "tag:action";
      #   type = "messages";
      # }
    ];

    filters = [
      # Example: { query = "from:github.com"; tags = "+github"; message = "GitHub"; }
    ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      accountsConfig = self.getModuleConfig "mail-stack.accounts";
      baseDataDir = "${config.xdg.dataHome}/${accountsConfig.baseDataDir}";
      mailDir = "${baseDataDir}/${accountsConfig.maildirPath}";
      accounts = accountsConfig.accounts;
      accountKeys = lib.attrNames accounts;

      buildServerConfig =
        (self.importFileFromOtherModuleSameInput {
          inherit args self;
          modulePath = "mail-stack.accounts";
        }).custom.buildServerConfig;

      primaryAccountKey = lib.findFirst (
        name: accounts.${name}.default or false
      ) (lib.head accountKeys) accountKeys;

      primaryAccount = if primaryAccountKey != null then accounts.${primaryAccountKey} else { };

      otherEmails = lib.remove (primaryAccount.address or "") (
        lib.mapAttrsToList (_: acc: acc.address) accounts
      );
    in
    {
      programs.notmuch = {
        enable = true;

        extraConfig = {
          database = {
            path = mailDir;
            backend = "glass";
            autocompact = "true";
          };
          user = {
            name = primaryAccount.realName or self.user.fullname;
            primary_email =
              if primaryAccount ? address then
                primaryAccount.address
              else
                throw "Primary account must have an email address";
          }
          // lib.optionalAttrs (otherEmails != [ ]) {
            other_email = lib.concatStringsSep ";" otherEmails;
          };
          index = {
            decrypt = "true";
          };
        };

        new = {
          tags = [
            "unread"
            "inbox"
          ];
          ignore = [
            ".mbsyncstate"
            ".uidvalidity"
            "dovecot*"
          ];
        };

        search.excludeTags = self.settings.excludeTags;

        maildir.synchronizeFlags = true;

        hooks.postNew = ''
          ${pkgs.afew}/bin/afew --tag --new
          ${pkgs.afew}/bin/afew --move-mails --new
          ${pkgs.afew}/bin/afew --tag --new
        '';
      };

      accounts.email.accounts = lib.mapAttrs (
        accountKey: account:
        if accountKey == primaryAccountKey then
          {
            notmuch = {
              enable = true;
              neomutt = {
                enable = true;
                virtualMailboxes = lib.mkForce [ ];
              };
            };
          }
        else
          {
            notmuch.enable = true;
          }
      ) accounts;

      home.file.".config/afew/config".text =
        let
          numOfFiltersPerAccount = 10;
        in
        ''
          [SpamFilter]

          [KillThreadsFilter]

          [ListMailsFilter]

          [MailMover]
          folders = ${
            lib.concatStringsSep " " (
              map (folder: "\"${folder}\"") (
                lib.flatten (
                  lib.mapAttrsToList (
                    accountKey: account:
                    let
                      serverConfig = buildServerConfig accountKey account;
                      folders = serverConfig.folders;
                    in
                    [
                      "${accountKey}/Inbox"
                      "${accountKey}/${folders.sent}"
                      "${accountKey}/${folders.drafts}"
                      "${accountKey}/${folders.trash}"
                      "${accountKey}/${folders.archive}"
                      "${accountKey}/${folders.spam}"
                    ]
                  ) accounts
                )
              )
            )
          }
          rename = true
          max_age = ${toString self.settings.maxAgeToProcess}

          ${lib.concatMapStringsSep "\n" (
            accountKey:
            let
              account = accounts.${accountKey};
              serverConfig = buildServerConfig accountKey account;
              folders = serverConfig.folders;
              archiveContainsAllMail = serverConfig.archiveContainsAllMail;

              allFolders = [
                "${accountKey}/Inbox"
                "${accountKey}/${folders.sent}"
                "${accountKey}/${folders.drafts}"
                "${accountKey}/${folders.trash}"
                "${accountKey}/${folders.archive}"
                "${accountKey}/${folders.spam}"
              ];
            in
            lib.concatMapStringsSep "\n" (
              srcFolder:
              let
                rules = lib.filter (rule: rule != "") [
                  (
                    if srcFolder != "${accountKey}/Inbox" then
                      "'tag:inbox AND NOT tag:trash AND NOT tag:spam':'${accountKey}/Inbox'"
                    else
                      ""
                  )
                  (
                    if srcFolder != "${accountKey}/${folders.sent}" then
                      "'tag:sent AND NOT tag:trash AND NOT tag:spam':'${accountKey}/${folders.sent}'"
                    else
                      ""
                  )
                  (
                    if
                      srcFolder != "${accountKey}/${folders.drafts}" && srcFolder != "${accountKey}/${folders.sent}"
                    then
                      "'tag:drafts AND NOT tag:trash AND NOT tag:spam':'${accountKey}/${folders.drafts}'"
                    else
                      ""
                  )
                  (
                    if srcFolder != "${accountKey}/${folders.trash}" then
                      "'tag:trash':'${accountKey}/${folders.trash}'"
                    else
                      ""
                  )
                  (
                    if srcFolder != "${accountKey}/${folders.archive}" then
                      "'tag:archive AND NOT tag:inbox AND NOT tag:sent AND NOT tag:drafts AND NOT tag:trash AND NOT tag:spam':'${accountKey}/${folders.archive}'"
                    else
                      ""
                  )
                  (
                    if srcFolder != "${accountKey}/${folders.spam}" then
                      "'(tag:spam${lib.optionalString self.settings.dkimFailAsSpam " OR tag:dkim-fail"}) AND NOT tag:trash':'${accountKey}/${folders.spam}'"
                    else
                      ""
                  )
                ];
                ruleString = lib.concatStringsSep " " rules;
              in
              lib.optionalString (ruleString != "") ''
                ${srcFolder} = ${ruleString}
              ''
            ) allFolders
          ) accountKeys}

          [SentMailsFilter]
          sent_tag = sent

          [MeFilter]
          me_tag = myself

          [HeaderMatchingFilter.1]
          header = From
          pattern = (noreply|no-reply|donotreply|automated|notification)@
          tags = +automated
          message = Tag automated emails

          [DKIMValidityFilter]

          ${lib.concatStringsSep "\n" (
            lib.imap1 (
              i: accountKey:
              let
                account = accounts.${accountKey};
                serverConfig = buildServerConfig accountKey account;
                folders = serverConfig.folders;
                baseIndex = (i - 1) * numOfFiltersPerAccount;
              in
              ''
                [Filter.${toString (baseIndex + 1)}]
                query = path:"${accountKey}/**"
                tags = +${accountKey}
                message = Tag ${accountKey} account

                [Filter.${toString (baseIndex + 2)}]
                query = folder:"${accountKey}/Inbox"
                tags = +inbox;-sent;-drafts;-archive;-trash;-spam
                message = Tag inbox emails

                [Filter.${toString (baseIndex + 3)}]
                query = folder:"${accountKey}/${folders.sent}"
                tags = +sent;-inbox;-drafts;-archive;-spam
                message = Tag sent emails

                [Filter.${toString (baseIndex + 4)}]
                query = folder:"${accountKey}/${folders.drafts}"
                tags = +drafts;-inbox;-sent;-archive;-trash;-spam
                message = Tag draft emails

                [Filter.${toString (baseIndex + 5)}]
                query = folder:"${accountKey}/${folders.trash}"
                tags = +trash;-inbox;-sent;-drafts;-archive;-spam
                message = Tag trash emails

                [Filter.${toString (baseIndex + 6)}]
                query = folder:"${accountKey}/${folders.archive}" AND NOT folder:"${accountKey}/Inbox"
                tags = +archive;-inbox;-sent;-drafts;-spam
                message = Tag archive emails

                [Filter.${toString (baseIndex + 7)}]
                query = folder:"${accountKey}/${folders.spam}"
                tags = +spam;-inbox;-sent;-drafts;-archive
                message = Tag spam emails

                ${lib.optionalString self.settings.dkimFailAsSpam ''
                  [Filter.${toString (baseIndex + 8)}]
                  query = tag:dkim-fail
                  tags = +spam
                  message = Tag DKIM failed emails as spam
                ''}

                [Filter.${toString (baseIndex + 9)}]
                query = tag:new
                tags = -new
                message = Remove new tag from processed messages

                ${lib.optionalString (!serverConfig.archiveContainsAllMail) ''
                  [Filter.${toString (baseIndex + numOfFiltersPerAccount)}]
                  query = folder:"${accountKey}/${folders.archive}"
                  tags = -inbox
                  message = Remove inbox tag from ${accountKey} archive
                ''}
              ''
            ) accountKeys
          )}

          ${lib.concatStringsSep "\n" (
            lib.imap1 (i: filter: ''
              [Filter.${toString (i + (lib.length accountKeys * numOfFiltersPerAccount))}]
              query = ${lib.escapeShellArg filter.query}
              tags = ${filter.tags}
              message = ${lib.escapeShellArg filter.message}
            '') self.settings.filters
          )}

          ${lib.concatStringsSep "\n" (
            lib.concatLists (
              lib.imap1 (
                accountIndex: accountKey:
                let
                  account = accounts.${accountKey};
                  accountFilters = account.filters or [ ];
                  baseFilterIndex =
                    (lib.length self.settings.filters) + (lib.length accountKeys * numOfFiltersPerAccount);
                  accountBaseIndex = baseFilterIndex + ((accountIndex - 1) * 50);
                in
                lib.imap1 (filterIndex: filter: ''
                  [Filter.${toString (accountBaseIndex + filterIndex)}]
                  query = path:${accountKey}/** AND (${filter.query})
                  tags = ${filter.tags}
                  message = ${lib.escapeShellArg "${accountKey}: ${filter.message}"}
                '') accountFilters
              ) accountKeys
            )
          )}

        '';

      home.packages = [
        pkgs.afew
      ];

      home.file.".local/bin/scripts/notmuch-process-mails.sh" = {
        text =
          let
            archiveFoldersQuery = lib.concatStringsSep " OR " (
              lib.mapAttrsToList (
                accountKey: account:
                let
                  serverConfig = buildServerConfig accountKey account;
                  folders = serverConfig.folders;
                in
                "folder:\"${accountKey}/${folders.archive}\""
              ) accounts
            );
          in
          ''
            #!/usr/bin/env bash
            set -euo pipefail

            NO_LOCK_CHECK=false
            MOVE_FIRST=false

            while [[ $# -gt 0 ]]; do
              case $1 in
                --no-lock-check)
                  NO_LOCK_CHECK=true
                  shift
                  ;;
                --move-first)
                  MOVE_FIRST=true
                  shift
                  ;;
                *)
                  echo "Unknown argument: $1"
                  echo "Usage: $0 [--no-lock-check] [--move-first]"
                  exit 1
                  ;;
              esac
            done

            BLUE='\033[0;34m'
            GREEN='\033[0;32m'
            YELLOW='\033[1;33m'
            RED='\033[0;31m'
            RESET='\033[0m'

            if [ "$NO_LOCK_CHECK" = false ]; then
              RUNTIME_DIR="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}/runtime-$(id -u)}"
              LOCKDIR="$RUNTIME_DIR/process-mails.lock"

              mkdir -p "$RUNTIME_DIR"

              if ! mkdir "$LOCKDIR" 2>/dev/null; then
                echo -e "''${YELLOW}⚠️ Another mail processing instance is already running. Exiting.''${RESET}"
                exit 2
              fi

              cleanup() {
                rmdir "$LOCKDIR" 2>/dev/null || true
              }
              trap cleanup EXIT INT TERM
            fi

            update_database() {
              echo -e "''${YELLOW}🔍 Updating notmuch database with new/moved files...''${RESET}"
              ${pkgs.notmuch}/bin/notmuch new
            }

            retag_mails() {
              echo -e "''${YELLOW}🏷️  Retagging all mails based on current locations...''${RESET}"
              ${pkgs.afew}/bin/afew --tag --all -T ${toString self.settings.maxAgeToProcess}
            }

            move_mails() {
              echo -e "''${YELLOW}📦 Moving mails from non-archive folders (no date limit)...''${RESET}"
              ${pkgs.afew}/bin/afew --move-mails 'NOT (${archiveFoldersQuery})'

              echo -e "''${YELLOW}📦 Moving mails from archive folders (date-restricted)...''${RESET}"
              ${pkgs.afew}/bin/afew --move-mails -T ${toString self.settings.maxAgeToProcess} '${archiveFoldersQuery}'
            }

            echo -e "''${BLUE}🔄 Processing mail with afew...''${RESET}"

            if [ "$MOVE_FIRST" = true ]; then
              move_mails
              update_database
              retag_mails
            else
              update_database
              retag_mails
              move_mails
            fi

            echo -e "''${GREEN}✅ Mail processing complete.''${RESET}"
          '';
        executable = true;
      };
    };
}
