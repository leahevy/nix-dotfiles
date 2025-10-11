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

  defaults = {
    sleep = true;
    suspend = true;
    hibernate = true;
    hybridSleep = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      systemd.targets = {
        sleep.enable = self.settings.sleep;
        suspend.enable = self.settings.suspend;
        hibernate.enable = self.settings.hibernate;
        hybrid-sleep.enable = self.settings.hybridSleep;
      };
    };
}
