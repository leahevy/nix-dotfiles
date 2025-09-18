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
  name = "home-integrated";

  description = "Build modules for NixOS integrated home-manager configuration";

  submodules = {
    build = {
      core = {
        programs = true;
        utils = true;
        tokens = true;
        sops = true;
      };
      desktop = {
        desktop = true;
      };
      system = {
        dummy-files = true;
      }
      // (if self.host.impermanence or false then { impermanence = true; } else { });
    };
  };
}
