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
        path = true;
      };
      desktop = {
        desktop = true;
        terminal = true;
      };
      system = {
        dummy-files = true;
      };
    };
  };
}
