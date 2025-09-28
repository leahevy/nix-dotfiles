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
