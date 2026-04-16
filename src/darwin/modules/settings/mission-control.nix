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
  name = "mission-control";

  group = "settings";
  input = "darwin";

  submodules = {
    darwin = {
      settings = {
        main = true;
      };
    };
  };

  module = {
    darwin.home = config: {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              desktopAndDock = {
                missionControl = {
                  automaticallyRearrangeSpacesBasedOnMostRecentUse = false;
                  displaysHaveSeparateSpaces = true;
                  dragWindowsToTopOfScreenToEnterMissionControl = false;
                  groupWindowsByApplication = true;
                  whenSwitchingToAnApplicationSwitchToAspaceWithOpenWindowsForTheApplication = false;
                };
              };
            };
          };
        };
      };
    };
  };
}
