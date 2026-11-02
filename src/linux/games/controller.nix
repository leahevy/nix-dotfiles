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
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "kernel";
          kernel = true;
          string = "xone-wired \\S+: xone_wired_complete_data_in: process failed: -16";
        }
      ];
    };
    linux.system = config: {
      hardware.xone.enable = self.settings.enableXone;
    };
  };
}
