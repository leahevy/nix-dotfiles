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

  module = {
    linux.system = config: {
      boot.kernelModules = lib.mkIf (self.host.kernel.variant != "lts") [ "ntsync" ];
    };
  };
}
