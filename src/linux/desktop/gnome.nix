args@{
  lib,
  pkgs,
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

  disableOnDarwin = true;

  submodules = {
    linux = {
      desktop = {
        common = true;
      };
      desktop-modules = {
        xserver = true;
        fuzzel = true;
      };
    };
  };

  module = {
    init =
      config:
      lib.mkIf self.isEnabled {
        nx.preferences.desktop.programs.appLauncher = {
          name = "gnome-shell";
          package = pkgs.glib.bin;
          openCommand = [
            "gdbus"
            "call"
            "--session"
            "--dest"
            "org.gnome.Shell"
            "--object-path"
            "/org/gnome/Shell"
            "--method"
            "org.gnome.Shell.ShowApplications"
          ];
          desktopFile = null;
        };
      };

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
