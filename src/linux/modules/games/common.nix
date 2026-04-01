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
  name = "common";

  group = "games";
  input = "linux";

  on = {
    linux.system = config: {
      boot.kernelModules = lib.mkIf (self.host.kernel.variant != "lts") [ "ntsync" ];
    };
  };
}
