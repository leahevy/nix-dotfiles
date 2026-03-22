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
  name = "windows";

  group = "settings";
  input = "darwin";

  submodules = {
    darwin = {
      settings = {
        main = true;
      };
    };
  };

  on = {
    darwin.home = config: {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              desktopAndDock = {
                windows = {
                  askToKeepChangesWhenClosingDocuments = false;
                  closeWindowsWhenQuittingAnApplication = true;
                  dragWindowsToMenuBarToFillScreen = false;
                  dragWindowsToScreenEdgesToTile = false;
                  holdOptionKeyWhileDraggingWindowsToTile = false;
                  preferTabsWhenOpeningDocuments = "In Full Screen";
                  tiledWindowsHaveMargin = true;
                };
              };
            };
          };
        };
      };
    };
  };
}
