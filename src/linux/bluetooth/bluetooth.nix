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
  name = "bluetooth";

  group = "bluetooth";
  input = "linux";

  settings = {
    withBlueman = false;
    releaseSoftBlock = true;
  };

  module = {
    disabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "Bluetooth: hci[0-9]+: Failed to send firmware data \\(-38\\)";
          kernel = true;
        }
      ];
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.directoryWatches = [ "/var/lib/bluetooth" ];
      };
    };

    linux.system = config: {
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Experimental = true;
            FastConnectable = true;
          };
          Policy = {
            AutoEnable = true;
          };
        };
      };

      services.blueman.enable = lib.mkDefault self.settings.withBlueman;

      systemd.services."rfkill-unblock-bluetooth" = lib.mkIf self.settings.releaseSoftBlock {
        description = "Unblock Bluetooth from rfkill soft block";
        after = [ "bluetooth.service" ];
        wants = [ "bluetooth.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
        };
      };
    };
  };
}
