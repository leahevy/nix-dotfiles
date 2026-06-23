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
  name = "gnome-standalone";

  group = "style";
  input = "linux";

  disableOnDarwin = true;

  module = {
    standalone = config: {
      stylix.targets.gnome.enable = lib.mkForce true;
    };
  };
}
