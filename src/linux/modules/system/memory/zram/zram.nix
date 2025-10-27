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
  name = "zram";

  group = "memory";
  input = "linux";
  namespace = "system";

  defaults = {
    algorithm = "zstd";
    memoryPercent = 50;
  };

  assertions = [
    {
      assertion = self.settings.memoryPercent >= 1 && self.settings.memoryPercent <= 85;
      message = "Memory percent must be in this range: 1-85!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      zramSwap = {
        enable = true;
        algorithm = self.settings.algorithm;
        memoryPercent = self.settings.memoryPercent;
        priority = 10;
        swapDevices = 1;
      };
    };
}
