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

  on = {
    linux.system = config: {
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
  };
}
