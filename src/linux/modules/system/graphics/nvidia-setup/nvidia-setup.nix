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
        powerManagement = {
          enable = true;
          finegrained = false;
        };
        nvidiaPersistenced = true;
      };

      hardware.graphics = {
        extraPackages = with pkgs; [
          nvidia-vaapi-driver
        ];
      };
    };
}
