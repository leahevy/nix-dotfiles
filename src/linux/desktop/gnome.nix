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

  module = {
    linux.system = config: {
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;

      services.desktopManager.gnome.extraGSettingsOverrides = ''
        [org.gnome.shell]
        welcome-dialog-last-shown-version='999.999'
      '';

      stylix.targets.qt.platform = lib.mkForce "qtct";
      qt.platformTheme = lib.mkForce "gnome";

      environment.plasma6.excludePackages = with pkgs.kdePackages; [
        plasma-welcome
      ];
    };
  };
}
