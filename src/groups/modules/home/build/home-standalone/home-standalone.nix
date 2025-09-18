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
  name = "home-standalone";

  description = "Build modules for standalone home-manager configuration";

  submodules = {
    build = {
      core = {
        programs = true;
        utils = true;
        tokens = true;
        sops = true;
      };
      system = {
        dummy-files = true;
      }
      // (if self.user.impermanence or false then { impermanence = true; } else { });
    };
  };
}
