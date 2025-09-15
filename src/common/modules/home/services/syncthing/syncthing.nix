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
  name = "syncthing";

  defaults = {
    syncName = "";
    syncID = "";
    syncIPAddress = "";
    syncPort = 22000;
    trayEnabled = false;
    guiPort = 8384;
    versioningKeepNumbers = 10;
    shares = { };
    announceEnabled = false;
  };

  assertions = [
    {
      assertion = self.settings.syncName != null && self.settings.syncName != "";
      message = "syncName is not set!";
    }
    {
      assertion = self.settings.syncID != null && self.settings.syncID != "";
      message = "syncID is not set!";
    }
    {
      assertion = self.settings.syncIPAddress != null && self.settings.syncIPAddress != "";
      message = "syncIPAddress is not set!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      sops.secrets."${self.host.hostname}-syncthing-key" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "syncthing.key";
      };

      sops.secrets."${self.host.hostname}-syncthing-cert" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "syncthing.cert";
      };

      sops.secrets."${self.host.hostname}-syncthing-password" = {
        format = "binary";
        sopsFile = self.profile.secretsPath "syncthing.password";
      };

      systemd.user.services.syncthing = lib.mkIf (self.linux.isModuleEnabled "storage.luks-data-drive") {
        Unit = {
          After = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
          Requires = lib.mkAfter [ "nx-luks-data-drive-ready.service" ];
        };
      };

      services.syncthing = {
        enable = true;
        overrideDevices = true;
        overrideFolders = true;
        guiAddress = "127.0.0.1:${builtins.toString self.settings.guiPort}";
        passwordFile = config.sops.secrets."${self.host.hostname}-syncthing-password".path;
        extraOptions = [ "--no-default-folder" ];
        tray = self.settings.trayEnabled;
        key = "${config.sops.secrets."${self.host.hostname}-syncthing-key".path}";
        cert = "${config.sops.secrets."${self.host.hostname}-syncthing-cert".path}";
        settings = {
          options.urAccepted = -1;
          options.relaysEnabled = false;
          options.localAnnounceEnabled = self.settings.announceEnabled;
          devices = {
            "${self.settings.syncName}" = {
              addresses = [
                "tcp://${self.settings.syncIPAddress}:${builtins.toString self.settings.syncPort}"
              ];
              id = self.settings.syncID;
            };
          };
          folders = builtins.mapAttrs (folderId: localPath: {
            path = "${self.user.home}/${localPath}";
            devices = [ self.settings.syncName ];
            versioning = {
              type = "simple";
              params.keep = "${builtins.toString self.settings.versioningKeepNumbers}";
            };
          }) self.settings.shares;
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".local/state/syncthing"
        ];
        files = lib.mkIf self.settings.trayEnabled [
          ".config/syncthingtray.ini"
        ];
      };
    };
}
