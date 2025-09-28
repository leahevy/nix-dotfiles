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

  submodules = {
    linux = {
      desktop = {
        common = true;
      };
      desktop-modules = {
        xserver = true;
      };
    };
  };

  defaults = { };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop.gnome";
      message = "Requires linux.desktop.gnome home-manager module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.xserver.displayManager.gdm.enable = true;
      services.xserver.desktopManager.gnome.enable = true;

      services.xserver.desktopManager.gnome.extraGSettingsOverrides = ''
        [org.gnome.shell]
        welcome-dialog-last-shown-version='999.999'
      '';

      services.xserver.desktopManager.plasma5.excludePackages = with pkgs.libsForQt5; [
        plasma-welcome
      ];
    };
}
