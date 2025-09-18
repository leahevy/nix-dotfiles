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

  defaults = { };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop.common";
      message = "Requires linux.desktop.common nixos module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
    };
}
