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
  name = "gnome-standalone";

  group = "style";
  input = "linux";

  on = {
    standalone = config: {
      stylix.targets.gnome.enable = lib.mkForce true;
    };
  };
}
