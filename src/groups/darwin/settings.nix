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
  name = "settings";

  group = "darwin";
  input = "groups";

  submodules = {
    darwin.settings = [
      "finder"
      "dock"
      "hotcorners"
      "mission-control"
      "widgets"
      "windows"
      "stage-manager"
      "focus"
      "appearance"
      "notifications"
      "sound"
      "spotlight"
      "control-center"
      # "date-and-time"
      "privacy"
    ];
  };
}
