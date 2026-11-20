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
        {
          kernel = true;
          string = "BUG: KFENCE: memory corruption in gip_auth_get_transcript.*\\[xone_gip\\]";
        }
        {
          kernel = true;
          string = "gip_dispatch_pkt\\.isra\\.[0-9]+\\+0x[0-9a-f]+/0x[0-9a-f]+ \\[xone_gip\\]";
        }
      ];
    };
    linux.system = config: {
      hardware.xone.enable = self.settings.enableXone;
    };
  };
}
