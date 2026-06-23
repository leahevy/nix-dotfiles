args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "controller";

  group = "games";
  input = "linux";

  settings = {
    enableXone = true;
  };

  unfree = [
    "xow_dongle-firmware"
    "xone-dongle-firmware"
  ];

  module = {
    linux.system = config: {
      hardware.xone.enable = self.settings.enableXone;
    };
  };
}
