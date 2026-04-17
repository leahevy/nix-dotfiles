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

  module = {
    darwin.home = config: {
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
  };
}
