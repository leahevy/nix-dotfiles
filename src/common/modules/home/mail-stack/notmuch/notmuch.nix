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

      standardFolders = [
        "inbox"
        "sent"
        "drafts"
        "trash"
        "archive"
        "spam"
      ];

      capitalizeFolder =
        folderType: lib.toUpper (lib.substring 0 1 folderType) + lib.substring 1 (-1) folderType;

      globalVirtualMailboxes =
        (map (folderType: {
          name = capitalizeFolder folderType;
          query = "tag:${folderType}";
          type = "messages";
        }) standardFolders)
        ++ (map (accountKey: {
          name = accountKey;
          query = "tag:${accountKey}";
          type = "messages";
        }) accountKeys)
        ++ [
          {
            name = "All Mails";
            query = "*";
            type = "messages";
          }
        ]
        ++ self.settings.virtualMailboxes;

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
          ${pkgs.afew}/bin/afew --move-mails --all -T ${toString self.settings.maxAgeToProcess}
          ${pkgs.afew}/bin/afew --tag --all -T ${toString self.settings.maxAgeToProcess}
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
                virtualMailboxes = globalVirtualMailboxes;
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
          numOfFiltersPerAccount = 9;
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
                      "${accountKey}/INBOX"
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
                "${accountKey}/INBOX"
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
                    if srcFolder != "${accountKey}/INBOX" then
                      "'tag:inbox AND NOT tag:trash AND NOT tag:spam':'${accountKey}/INBOX'"
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
                    if srcFolder != "${accountKey}/${folders.drafts}" then
                      "'tag:drafts AND NOT tag:trash AND NOT tag:spam':'${accountKey}/${folders.drafts}'"
                    else
                      ""
                  )
                  (
                    if srcFolder != "${accountKey}/${folders.trash}" then
                      "'tag:deleted OR tag:trash':'${accountKey}/${folders.trash}'"
                    else
                      ""
                  )
                  (
                    if archiveContainsAllMail && srcFolder == "${accountKey}/INBOX" then
                      "'tag:archive AND NOT tag:inbox AND NOT tag:trash AND NOT tag:spam':'${accountKey}/${folders.archive}'"
                    else if !archiveContainsAllMail && srcFolder != "${accountKey}/${folders.archive}" then
                      "'tag:archive AND NOT tag:inbox AND NOT tag:trash AND NOT tag:spam':'${accountKey}/${folders.archive}'"
                    else
                      ""
                  )
                  (
                    if srcFolder != "${accountKey}/${folders.spam}" then
                      "'(tag:spam OR tag:dkim-fail) AND NOT tag:trash':'${accountKey}/${folders.spam}'"
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
                query = folder:"${accountKey}/**"
                tags = +${accountKey}
                message = Tag ${accountKey} account

                [Filter.${toString (baseIndex + 2)}]
                query = folder:"${accountKey}/INBOX"
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
                tags = +trash;+deleted;-inbox;-sent;-drafts;-archive;-spam
                message = Tag trash emails

                [Filter.${toString (baseIndex + 6)}]
                query = folder:"${accountKey}/${folders.archive}"
                tags = +archive;-inbox;-sent;-drafts;-spam
                message = Tag archive emails

                [Filter.${toString (baseIndex + 7)}]
                query = folder:"${accountKey}/${folders.spam}"
                tags = +spam;-inbox;-sent;-drafts;-archive
                message = Tag spam emails

                [Filter.${toString (baseIndex + 8)}]
                query = tag:dkim-fail
                tags = +spam
                message = Tag DKIM failed emails as spam

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

          [InboxFilter]
        '';

      home.packages = [
        pkgs.afew
      ];
    };
}
