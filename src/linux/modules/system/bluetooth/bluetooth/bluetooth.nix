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
    };
}
