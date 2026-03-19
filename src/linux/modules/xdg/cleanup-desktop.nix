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
  name = "cleanup-desktop";

  group = "xdg";
  input = "linux";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      xdg.desktopEntries = {
        "nvidia-settings" = lib.mkIf (self.isModuleEnabled "graphics.nvidia-setup") {
          name = "NVIDIA X Server Settings";
          noDisplay = true;
        };

        "kvantummanager" = {
          name = "Kvantum Manager";
          noDisplay = true;
        };

        "qt5ct" = {
          name = "Qt5 Settings";
          noDisplay = true;
        };

        "qt6ct" = {
          name = "Qt6 Settings";
          noDisplay = true;
        };

        "org.kde.plasma-systemmonitor" = {
          name = "System Monitor";
          noDisplay = true;
        };

        "systemsettings" = {
          name = "System Settings";
          noDisplay = true;
        };

        "kdesystemsettings" = {
          name = "KDE System Settings";
          noDisplay = true;
        };

        "org.kde.spectacle" = {
          name = "Spectacle";
          noDisplay = true;
        };
      };
    };
}
