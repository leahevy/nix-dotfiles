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
  name = "nvidia-setup";

  unfree = [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];

  defaults = {
    withPowerManagement = true;
  };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "graphics.nvidia-setup";
      message = "Requires linux.graphics.nvidia-setup home module to be enabled for integrated user!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      hardware.nvidia = {
        powerManagement = lib.mkIf self.settings.withPowerManagement {
          enable = true;
          finegrained = false;
        };
        nvidiaPersistenced = self.settings.withPowerManagement;
      };

      hardware.graphics = {
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
        ];
      };
    };
}
