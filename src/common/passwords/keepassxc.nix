args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "keepassxc";

  group = "passwords";
  input = "common";

  options = {
    lockIdleSeconds = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 900;
      description = "Seconds of idle time before locking the database. Set to 0 to disable idle lock.";
    };
  };

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "keepassxc" ];
    };

    darwin.home = config: {
      programs.keepassxc = {
        package = null;
      };
    };

    home = { config, lockIdleSeconds, ... }: {
      programs.keepassxc = {
        enable = true;
        settings = {
          General = {
            BackupBeforeSave = true;
            BackupFilePathPattern = "{DB_FILENAME}.old.kdbx";
            ConfigVersion = 2;
            FaviconDownloadTimeout = 20;
            HideWindowOnCopy = true;
            MinimizeAfterUnlock = false;
            MinimizeOnOpenUrl = false;
            UseAtomicSaves = false;
          };

          Browser = {
            Enabled = true;
            UpdateBinaryPath = false;
          };

          GUI = {
            ColorPasswords = true;
            MinimizeOnClose = false;
            MinimizeOnStartup = false;
            MinimizeToTray = false;
            ShowExpiredEntriesOnDatabaseUnlockOffsetDays = 6;
            ShowTrayIcon = true;
            TrayIconAppearance = "colorful";
            ApplicationTheme = "dark";
            AdvancedSettings = true;
            CompactMode = true;
          };

          PasswordGenerator = {
            AdditionalChars = "";
            ExcludedChars = "l0";
          };

          SSHAgent = {
            Enabled = true;
          };

          Security = {
            ClearClipboardTimeout = 25;
            ClearSearch = true;
            IconDownloadFallback = true;
            LockDatabaseScreenLock = false;
            LockDatabaseIdle = lockIdleSeconds > 0;
            LockDatabaseIdleSeconds = lockIdleSeconds;
          };
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/keepassxc"
          ".cache/keepassxc"
        ];
      };
    };

    linux.standalone = config: {
      programs.keepassxc.package = pkgs.symlinkJoin {
        name = "keepassxc-xcb";
        paths = [ pkgs.keepassxc ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/keepassxc \
            --set GDK_BACKEND x11 \
            --set QT_QPA_PLATFORM xcb
        '';
      };
    };

    ifEnabled.common.browser.firefox = {
      enabled =
        config:
        lib.mkIf (!config.nx.common.passwords.bitwarden.enable) {
          nx.common.browser.firefox.extensions.keepassxc-browser = {
            addonId = "keepassxc-browser@keepassxc.org";
            slug = "keepassxc-browser";
            showInToolbar = true;
            allowedInPrivateWindows = false;
          };

          nx.common.browser.firefox.firejailExtraRules = [
            "noblacklist \${RUNUSER}/app"
            "whitelist \${RUNUSER}/app/org.keepassxc.KeePassXC"
            "whitelist \${RUNUSER}/kpxc_server"
            "whitelist \${RUNUSER}/org.keepassxc.KeePassXC.BrowserServer"
          ];
        };
    };

    ifEnabled.linux.desktop.niri.home =
      config:
      let
        appId = if self.user.isStandalone then "KeePassXC" else "org.keepassxc.KeePassXC";
      in
      {
        programs.niri = {
          settings = {
            window-rules = [
              {
                matches = [
                  {
                    app-id = appId;
                    title = ".*\\.kdbx.* - KeePassXC";
                  }
                ];
                open-on-workspace = "scratch";
                open-floating = true;
                open-focused = false;
                block-out-from = "screencast";
              }
            ];
          };
        };
      };

    when = [
      {
        modules.linux.desktop.niri = true;
        modules.common.passwords.bitwarden = false;
        do.home =
          config:
          let
            appId = if self.user.isStandalone then "KeePassXC" else "org.keepassxc.KeePassXC";
          in
          {
            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+K" = {
                action = spawn-sh "niri-scratchpad --app-id ${appId} --all-windows --spawn keepassxc";
                hotkey-overlay.title = "Apps:KeepassXC";
              };
            };
          };
      }
      {
        modules.linux.desktop.niri = true;
        modules.common.passwords.bitwarden = true;
        do.home =
          config:
          let
            appId = if self.user.isStandalone then "KeePassXC" else "org.keepassxc.KeePassXC";
          in
          {
            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+U" = {
                action = spawn-sh "niri-scratchpad --app-id ${appId} --all-windows --spawn keepassxc";
                hotkey-overlay.title = "Apps:KeepassXC";
              };
            };
          };
      }
    ];
  };
}
