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

  group = "build";
  input = "groups";
  namespace = "home";

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
      }
      // (if self.host.impermanence or false then { impermanence = true; } else { });
    };
  };
}
