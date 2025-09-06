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
  configuration =
    context@{ config, options, ... }:
    {
      system.autoUpgrade = {
        enable = true;
        flake = self.inputs.self.outPath;
        flags = [
          "-L"
        ];
        dates = "19:15";
        randomizedDelaySec = "15min";
        persistent = true;
        allowReboot = true;
        rebootWindow = {
          lower = "23:00";
          upper = "06:00";
        };
      };
    };
}
