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
  name = "date-and-time";

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

  error = "Broken as nix-plist-manager tries to call 'defaults' without absolute path for general.* settings";

  settings = {
    use24HourTime = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        options = {
          applications = {
            systemSettings = {
              general = {
                dateAndTime = {
                  "24HourTime" = self.settings.use24HourTime;
                };
              };
            };
          };
        };
      };
    };
}
