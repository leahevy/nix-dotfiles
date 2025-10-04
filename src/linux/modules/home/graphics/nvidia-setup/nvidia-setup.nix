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

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false)
        || (self.host.isModuleEnabled or (x: false)) "graphics.nvidia-setup";
      message = "For integrated users: Requires linux.graphics.nvidia-setup system module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.persistence."${self.persist}" = {
        directories = [
          ".cache/nvidia"
        ];
      };
    };
}
