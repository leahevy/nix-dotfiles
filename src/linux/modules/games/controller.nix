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
  name = "controller";

  group = "games";
  input = "linux";

  settings = {
    enableXone = true;
  };

  module = {
    linux.system = config: {
      hardware.xone.enable = self.settings.enableXone;
    };
  };
}
