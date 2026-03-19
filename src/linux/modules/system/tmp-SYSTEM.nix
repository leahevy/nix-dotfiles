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

  group = "system";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      boot.tmp.useTmpfs = true;
      boot.tmp.tmpfsSize = self.host.settings.system.tmpSize;

      nix.settings.build-dir = "/var/nix-builds";

      systemd.tmpfiles.rules = [
        "d /var/tmp 1777 root root -"
        "d /var/nix-builds 0755 root root -"
      ];
    };
}
