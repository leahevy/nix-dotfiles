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

  group = "primary";
  input = "desktops";
  namespace = "home";

  settings = {
    name = "gnome";

    preferences = {
      wallet = {
        package = pkgs.gnome-keyring;
      };
      systemSettings = {
        package = pkgs.gnome-control-center;
      };
      networkSettings = {
        package = pkgs.gnome-control-center;
      };
      taskManager = {
        package = pkgs.gnome-system-monitor;
      };
    };
  };
}
