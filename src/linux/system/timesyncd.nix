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
  name = "timesyncd";

  group = "system";
  input = "linux";

  module = {
    linux.system = config: {
      services.timesyncd = {
        enable = lib.mkForce true;
      };
    };
  };
}
