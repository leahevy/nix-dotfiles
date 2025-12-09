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
    {
      hardware.enableRedistributableFirmware = self.host.settings.system.firmware.redistributable;
      hardware.enableAllFirmware = self.host.settings.system.firmware.unfree;
    };
}
