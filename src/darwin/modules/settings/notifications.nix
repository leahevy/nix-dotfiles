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
  name = "notifications";

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
            systemSettings = {
              notifications = {
                notificationCenter = {
                  showPreviews = "When Unlocked";
                  summarizeNotifications = true;
                };
              };
            };
          };
        };
      };
    };
  };
}
