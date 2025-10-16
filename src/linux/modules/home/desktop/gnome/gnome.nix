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
  name = "gnome";

  group = "desktop";
  input = "linux";
  namespace = "home";

  submodules = {
    linux = {
      desktop = {
        common = true;
      };
    };
  };

  defaults = { };

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false) || (self.host.isModuleEnabled or (x: false)) "desktop.gnome";
      message = "Requires linux.desktop.gnome nixos module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
    };
}
