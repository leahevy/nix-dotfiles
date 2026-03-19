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
  namespace = "system";

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

  settings = { };

  assertions = [
    {
      assertion = self.user.isModuleEnabled "desktop.gnome";
      message = "Requires linux.desktop.gnome home-manager module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;

      services.desktopManager.gnome.extraGSettingsOverrides = ''
        [org.gnome.shell]
        welcome-dialog-last-shown-version='999.999'
      '';

      services.desktopManager.plasma5.excludePackages = with pkgs.libsForQt5; [
        plasma-welcome
      ];
    };
}
