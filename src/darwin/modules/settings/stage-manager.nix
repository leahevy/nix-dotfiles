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
  name = "stage-manager";

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
    enabled = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              desktopAndDock = {
                desktopAndStageManager = {
                  stageManager = self.settings.enabled;
                  clickWallpaperToRevealDesktop = "Only in Stage Manager";
                  showRecentAppsInStageManager = true;
                  showWindowsFromAnApplication = "All at Once";
                  showItems = {
                    inStageManager = true;
                    onDesktop = false;
                  };
                };
              };
            };
          };
        };
      };
    };
}
