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

  group = "desktop";
  input = "linux";
  namespace = "home";

  submodules = {
    linux = {
      desktop-modules = {
        keyd = true;
      };
    };
  };

  settings = { };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop.common";
      message = "Requires linux.desktop.common nixos module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        sessionVariables = {
          QT_QPA_PLATFORMTHEME = lib.mkForce "gtk3";
          QT_QPA_PLATFORMTHEME_QT6 = lib.mkForce "gtk3";
        };
      };
    };
}
