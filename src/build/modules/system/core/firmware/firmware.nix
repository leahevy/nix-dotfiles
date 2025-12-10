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
  name = "firmware";
  group = "core";
  input = "build";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    let
      modeSwitchDevices = self.host.settings.system.firmware.modeSwitchDevices or [ ];

      generateUdevRule =
        device:
        let
          parts = lib.splitString ":" device.device;
          vendor = lib.head parts;
          product = lib.last parts;
        in
        if (lib.length parts != 2) then
          throw "Invalid device format '${device.device}': must be 'vendor:product'"
        else if (vendor == "" || product == "") then
          throw "Invalid device format '${device.device}': vendor and product cannot be empty"
        else
          ''ATTR{idVendor}=="${vendor}", ATTR{idProduct}=="${product}", RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch -v ${vendor} -p ${product} ${device.flags}"'';

      udevRules = lib.concatMapStringsSep "\n" generateUdevRule modeSwitchDevices;
    in
    {
      hardware.enableRedistributableFirmware = self.host.settings.system.firmware.redistributable;
      hardware.enableAllFirmware = self.host.settings.system.firmware.unfree;
      hardware.usb-modeswitch.enable = true;

      environment.systemPackages = lib.optionals (modeSwitchDevices != [ ]) [ pkgs.usb-modeswitch ];

      services.udev.extraRules = lib.optionalString (modeSwitchDevices != [ ]) udevRules;
    };
}
