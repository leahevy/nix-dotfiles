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
  name = "bluetooth";

  group = "bluetooth";
  input = "linux";
  namespace = "system";

  settings = {
    withBlueman = false;
    releaseSoftBlock = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
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
}
