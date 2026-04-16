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
  name = "spotlight";

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
              spotlight = {
                helpAppleImproveSearch = false;
              };
            };
          };
        };
      };
    };
  };
}
