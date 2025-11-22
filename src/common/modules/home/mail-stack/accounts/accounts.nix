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

    # providerName = {
    #   imap = {
    #     host = "imap.example.com";           # Or hostPattern = "imap.%DOMAIN%"
    #     port = 993;                          # Optional: defaults based on ssl
    #     ssl = true;                          # true=IMAPS(993), false=STARTTLS(143)
    #   };
    #   smtp = {
    #     host = "smtp.example.com";           # Or hostPattern = "smtp.%DOMAIN%"
    #     port = 587;                          # Optional: defaults based on ssl
    #     ssl = false;                         # false=STARTTLS(587), true=SSL(465)
    #   };
    #   folders = {
    #     sent = "Sent";
    #     drafts = "Drafts";
    #     trash = "Trash";
    #     archive = "Archive";
    #   };
    # };
    providers = {
      "gmail.com" = {
        imap = {
          host = "imap.gmail.com";
          ssl = true;
        };
        smtp = {
          host = "smtp.gmail.com";
          ssl = false;
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
          ssl = true;
        };
        smtp = {
          hostPattern = "smtp.%DOMAIN%";
          ssl = false;
        };
        folders = {
          sent = "Sent";
          drafts = "Drafts";
          trash = "Trash";
          archive = "Archive";
        };
      };
    };
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

      providers = self.settings.providers;

      getProviderConfig =
        account:
        let
          providerKey =
            if account ? provider then account.provider else lib.last (lib.splitString "@" account.address);
        in
        providers.${providerKey} or providers.default;

      buildServerConfig =
        accountKey: account:
        let
          providerConfig = getProviderConfig account;
          domain = lib.last (lib.splitString "@" account.address);
          imapSsl = providerConfig.imap.ssl or true;
          defaultImapPort = if imapSsl then 993 else 143;
          smtpSsl = providerConfig.smtp.ssl or false;
          defaultSmtpPort = if smtpSsl then 465 else 587;
        in
        {
          imap = {
            host =
              if providerConfig.imap ? hostPattern then
                lib.replaceStrings [ "%DOMAIN%" ] [ domain ] providerConfig.imap.hostPattern
              else
                providerConfig.imap.host;
            port = providerConfig.imap.port or defaultImapPort;
            ssl = imapSsl;
          };
          smtp = {
            host =
              if providerConfig.smtp ? hostPattern then
                lib.replaceStrings [ "%DOMAIN%" ] [ domain ] providerConfig.smtp.hostPattern
              else
                providerConfig.smtp.host;
            port = providerConfig.smtp.port or defaultSmtpPort;
            ssl = smtpSsl;
          };
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
              host = serverConfig.imap.host;
              port = serverConfig.imap.port;
              tls = {
                enable = true;
                useStartTls = !serverConfig.imap.ssl;
              };
            };

            smtp = {
              host = serverConfig.smtp.host;
              port = serverConfig.smtp.port;
              tls = {
                enable = true;
                useStartTls = !serverConfig.smtp.ssl;
              };
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
