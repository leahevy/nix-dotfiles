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

    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          service = "bluetooth.service";
          tag = "bluetoothd";
          string = "Failed to set default system config for hci[0-9]+";
        }
        {
          service = "dbus-broker.service";
          tag = "dbus-broker";
          string = "A security policy denied [^ ]+ to send method call /midi/profile:org\\.bluez\\.GattProfile1\\.Release to [^ ]+\\.";
        }
      ];
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.directoryWatches = [ "/var/lib/bluetooth" ];
        nx.linux.security.aide.excludePathsRegex = [
          "/var/lib/bluetooth/[0-9A-Fa-f:]+/cache(/|$)"
          "/var/lib/bluetooth/[0-9A-Fa-f:]+/attributes$"
        ];
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
