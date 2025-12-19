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
}
