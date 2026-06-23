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

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "keepassxc" ];
    };

    darwin.home = config: {
      programs.keepassxc = {
        package = null;
      };
    };

    home = config: {
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

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+U" = {
              action = spawn-sh "niri-scratchpad --app-id org.keepassxc.KeePassXC --all-windows --spawn keepassxc";
              hotkey-overlay.title = "Apps:KeepassXC";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "org.keepassxc.KeePassXC";
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
  };
}
