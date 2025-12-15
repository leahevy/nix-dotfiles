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
  name = "keepassxc";

  group = "passwords";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
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

      programs.niri = lib.mkIf isNiriEnabled {
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
}
