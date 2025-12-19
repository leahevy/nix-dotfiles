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
  name = "hotcorners";

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
    topLeft = "-";
    topRight = "Notification Center";
    bottomLeft = "-";
    bottomRight = "-";
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              desktopAndDock = {
                hotCorners = {
                  bottomLeft = self.settings.bottomLeft;
                  bottomRight = self.settings.bottomRight;
                  topLeft = self.settings.topLeft;
                  topRight = self.settings.topRight;
                };
              };
            };
          };
        };
      };
    };
}
