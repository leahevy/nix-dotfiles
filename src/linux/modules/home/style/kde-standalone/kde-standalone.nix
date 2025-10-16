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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      config = lib.mkIf (self.user.isStandalone && self.isLinux) {
        stylix.targets.kde.enable = lib.mkForce true;
      };
    };
}
