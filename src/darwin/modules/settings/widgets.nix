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
  name = "widgets";

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
                widgets = {
                  useIphoneWidgets = false;
                  widgetStyle = "Automatic";
                  showWidgets = {
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
  };
}
