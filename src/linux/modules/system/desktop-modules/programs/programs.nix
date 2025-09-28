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
let
  homeModuleConfig = self.user.getModuleConfig "desktop-modules.programs";
  desktopPreference = self.user.settings.desktopPreference;
  isKDE = desktopPreference == "kde";
  isGnome = desktopPreference == "gnome";
in
{
  name = "programs";

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop-modules.programs";
      message = "System desktop-modules.programs requires home desktop-modules.programs to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.gnome.gnome-keyring.enable = lib.mkForce isGnome;
    };
}
