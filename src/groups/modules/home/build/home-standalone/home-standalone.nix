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
        nx-config-standalone = true;
      };
      desktop = {
        desktop = true;
        terminal = true;
      };
      system = {
        dummy-files = true;
      };
    };
  }
  // lib.optionalAttrs self.isDarwin {
    darwin = {
      software = {
        homebrew = true;
      };
    };
  };
}
