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
  namespace = "home";

  submodules = {
    darwin = {
      settings = {
        main = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
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
}
