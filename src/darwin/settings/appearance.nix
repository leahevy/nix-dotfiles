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

  module = {
    darwin.home = config: {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              appearance = {
                accentColor =
                  if config.nx.preferences.theme.tint == "green" then
                    "Green"
                  else if config.nx.preferences.theme.tint == "blue" then
                    "Blue"
                  else if config.nx.preferences.theme.tint == "purple" then
                    "Purple"
                  else if config.nx.preferences.theme.tint == "pink" then
                    "Pink"
                  else if config.nx.preferences.theme.tint == "red" then
                    "Red"
                  else if config.nx.preferences.theme.tint == "orange" then
                    "Orange"
                  else if config.nx.preferences.theme.tint == "yellow" then
                    "Yellow"
                  else
                    "Graphite";

                allowWallpaperTintingInWindows = true;

                appearance =
                  if config.nx.preferences.theme.variant == "dark" then
                    "Dark"
                  else if config.nx.preferences.theme.variant == "light" then
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
  };
}
