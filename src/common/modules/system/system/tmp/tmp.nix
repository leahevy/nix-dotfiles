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
  name = "tmp";

  configuration =
    context@{ config, options, ... }:
    {
      boot.tmp.useTmpfs = true;
      boot.tmp.tmpfsSize = self.host.settings.system.tmpSize;

      nix.settings.build-dir = "/var/tmp";

      systemd.tmpfiles.rules = [
        "d /var/tmp 1777 root root -"
      ];
    };
}
