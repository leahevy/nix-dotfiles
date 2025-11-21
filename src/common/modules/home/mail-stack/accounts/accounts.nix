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
  name = "accounts";
  group = "mail-stack";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      mail-stack = {
        passwords = true;
      };
    };
  };

  settings = {
    # accounts = {
    #   personal = {
    #     address = "user@domain.com";       # Required: email address
    #     realName = "User Name";            # Required: display name
    #     username = "user@domain.com";      # Optional: defaults to address
    #     default = true;                    # Required: exactly one must be true
    #     ssl = false;                       # Optional: false=STARTTLS(587), true=SSL(465)
    #     port = 587;                        # Optional: port override
    #   };
    # };
    accounts = { };

    baseDataDir = "mails";
    maildirPath = "maildir";
  };

  assertions = [
    {
      assertion = self.settings.accounts != { };
      message = "Accounts cannot be empty!";
    }
    {
      assertion =
        let
          defaultAccounts = lib.filterAttrs (_: acc: acc.default or false) self.settings.accounts;
        in
        lib.length (lib.attrNames defaultAccounts) == 1;
      message = "Exactly one account must have default = true.";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      baseDataDir = "${config.xdg.dataHome}/${self.settings.baseDataDir}";
      mailDir = "${baseDataDir}/${self.settings.maildirPath}";

      mkPasswordCommand =
        (self.importFileFromOtherModuleSameInput {
          inherit args self;
          modulePath = "mail-stack.passwords";
        }).custom.mkPasswordCommand;

      passwordsConfig = self.getModuleConfig "mail-stack.passwords";

      providers = {
        "gmail.com" = {
          imap = {
            host = "imap.gmail.com";
            port = 993;
          };
          folders = {
            sent = "[Gmail]/Sent Mail";
            drafts = "[Gmail]/Drafts";
            trash = "[Gmail]/Trash";
            archive = "[Gmail]/All Mail";
          };
        };
        default = {
          imap = {
            hostPattern = "imap.%DOMAIN%";
            port = 993;
          };
          folders = {
            sent = "Sent";
            drafts = "Drafts";
            trash = "Trash";
            archive = "Archive";
          };
        };
      };

      getProviderConfig =
        account:
        let
          domain = lib.last (lib.splitString "@" account.address);
        in
        providers.${domain} or providers.default;

      buildServerConfig =
        accountKey: account:
        let
          providerConfig = getProviderConfig account;
          domain = lib.last (lib.splitString "@" account.address);
        in
        {
          host =
            if providerConfig.imap ? hostPattern then
              lib.replaceStrings [ "%DOMAIN%" ] [ domain ] providerConfig.imap.hostPattern
            else
              providerConfig.imap.host;
          inherit (providerConfig.imap) port;
          folders = providerConfig.folders;
        };

    in
    {
      accounts.email = {
        maildirBasePath = mailDir;

        accounts = lib.mapAttrs (
          accountKey: account:
          let
            serverConfig = buildServerConfig accountKey account;
          in
          {
            address = account.address;
            userName = account.username or account.address;
            realName = account.realName or account.address;
            passwordCommand = mkPasswordCommand accountKey passwordsConfig.service;
            primary = account.default or false;

            imap = {
              host = serverConfig.host;
              port = serverConfig.port;
              tls.enable = true;
            };

            folders = lib.removeAttrs serverConfig.folders [ "archive" ];
          }
        ) self.settings.accounts;
      };

      home.activation.accounts-maildir = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ${mailDir} || true
      '';

      home.persistence."${self.persist}" = {
        directories = [
          (lib.removePrefix "${config.home.homeDirectory}/" baseDataDir)
        ];
      };
    };
}
