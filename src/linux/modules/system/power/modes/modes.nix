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
  name = "modes";

  configuration =
    context@{ config, options, ... }:
    {
      systemd.targets = {
        sleep.enable = true;
        suspend.enable = true;
        hibernate.enable = true;
        hybrid-sleep.enable = true;
      };
    };
}
