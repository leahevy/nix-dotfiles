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
  name = "usb-access";

  group = "storage";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      users.groups.usb-disk = { };

      users.users.${self.host.mainUser.username} = {
        extraGroups = [ "usb-disk" ];
      };

      services.udev.extraRules = ''
        SUBSYSTEM=="block", ENV{ID_BUS}=="usb", GROUP="usb-disk", MODE="0660"
      '';
    };
}
