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
  name = "kde-standalone";
  group = "style";
  input = "linux";

  module = {
    standalone = config: {
      stylix.targets.kde.enable = lib.mkForce true;
    };
  };
}
