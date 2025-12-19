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
  name = "dock";

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

  settings = {
    dockPosition = "Bottom";
    onTitleClick = "Zoom";
    minimizeEffect = "Scale Effect";
    animate = false;
    dockSize = 38;
    hideDockDelay = 0.0;
    hideDockDuration = 0.2;
    autoHideDock = true;
    magnificationSize = 70;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              desktopAndDock = {
                dock = {
                  positionOnScreen = self.settings.dockPosition;
                  showSuggestedAndRecentAppsInDock = false;
                  size = self.settings.dockSize;
                  showIndicatorsForOpenApplications = true;
                  animateOpeningApplications = self.settings.animate;
                  minimizeWindowsUsing = self.settings.minimizeEffect;
                  minimizeWindowsIntoApplicationIcon = false;
                  doubleClickAWindowsTitleBarTo = self.settings.onTitleClick;
                  automaticallyHideAndShowTheDock = {
                    enabled = self.settings.autoHideDock;
                    delay = self.settings.hideDockDelay;
                    duration = self.settings.hideDockDuration;
                  };
                  magnification = {
                    enabled =
                      if self.settings.magnificationSize != null && self.settings.magnificationSize >= 30 then
                        true
                      else
                        false;
                    size = if self.settings.magnificationSize < 30 then 30 else self.settings.magnificationSize;
                  };
                };
              };
            };
          };
        };
      };
    };
}
