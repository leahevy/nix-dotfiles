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
  name = "settings";

  group = "darwin";
  input = "groups";
  namespace = "home";

  submodules = {
    darwin = {
      settings = {
        finder = true;
        dock = true;
        hotcorners = true;
        mission-control = true;
        widgets = true;
        windows = true;
        stage-manager = true;
        focus = true;
        appearance = true;
        date-and-time = false;
        notifications = true;
        sound = true;
        spotlight = true;
        control-center = true;
      };
    };
  };
}
