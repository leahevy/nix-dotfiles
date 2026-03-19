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
}
