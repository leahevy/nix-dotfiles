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
  name = "finder";

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
            finder = {
              menuBar = {
                view = {
                  showPathBar = true;
                  showSidebar = false;
                  showStatusBar = true;
                  showTabBar = true;
                };
              };
              settings = {
                general = {
                  openFoldersInTabsInsteadOfNewWindows = true;
                  showTheseItemsOnTheDesktop = {
                    cdsDvdsAndiPods = false;
                    connectedServers = false;
                    externalDisks = false;
                    hardDisks = false;
                  };
                };
                sidebar = {
                  recentTags = false;
                };
                advanced = {
                  removeItemsFromTheTrashAfter30Days = true;
                  showAllFilenameExtensions = true;
                  showWarningBeforeChangingAnExtension = false;
                  showWarningBeforeEmptyingTheTrash = false;
                  showWarningBeforeRemovingFromiCloudDrive = false;
                  whenPerformingASearch = "Search the Current Folder";
                  keepFoldersOnTop = {
                    inWindowsWhenSortingByName = false;
                    onDesktop = false;
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
