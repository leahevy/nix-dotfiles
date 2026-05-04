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

  group = "power";
  input = "linux";

  disableOnVirtual = true;

  settings = {
    sleep = true;
    suspend = true;
    hibernate = true;
    hybridSleep = true;
  };

  module = {
    linux.system = config: {
      systemd.targets = {
        sleep.enable = self.settings.sleep;
        suspend.enable = self.settings.suspend;
        hibernate.enable = self.settings.hibernate;
        hybrid-sleep.enable = self.settings.hybridSleep;
      };
    };
  };
}
