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
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = true;
        hybrid-sleep.enable = false;
      };
    };
}
