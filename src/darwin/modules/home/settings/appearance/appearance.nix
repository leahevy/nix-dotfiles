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
  name = "appearance";

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
    sidebarIconSize = "Medium";
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              appearance = {
                accentColor =
                  if self.theme.tint == "green" then
                    "Green"
                  else if self.theme.tint == "blue" then
                    "Blue"
                  else if self.theme.tint == "purple" then
                    "Purple"
                  else if self.theme.tint == "pink" then
                    "Pink"
                  else if self.theme.tint == "red" then
                    "Red"
                  else if self.theme.tint == "orange" then
                    "Orange"
                  else if self.theme.tint == "yellow" then
                    "Yellow"
                  else
                    "Graphite";

                allowWallpaperTintingInWindows = true;

                appearance =
                  if self.theme.variant == "dark" then
                    "Dark"
                  else if self.theme.variant == "light" then
                    "Light"
                  else
                    "Auto";

                clickInTheScrollBarTo = "Jump to the spot that's clicked";
                showScrollBars = "Always";
                sidebarIconSize = self.settings.sidebarIconSize;
              };
            };
          };
        };
      };
    };
}
