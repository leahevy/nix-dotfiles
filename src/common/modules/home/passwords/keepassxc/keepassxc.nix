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
            "Ctrl+Mod+Alt+U" = {
              action = spawn-sh "niri-scratchpad --app-id org.keepassxc.KeePassXC --spawn keepassxc";
              hotkey-overlay.title = "Apps:Password manager";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "org.keepassxc.KeePassXC"; } ];
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
