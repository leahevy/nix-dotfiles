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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      config = lib.mkIf (self.user.isStandalone && self.isLinux) {
        stylix.targets.gnome.enable = lib.mkForce true;
      };
    };
}
