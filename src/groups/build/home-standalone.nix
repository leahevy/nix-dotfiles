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

  submodules = {
    build = {
      core = [
        "programs"
        "utils"
        "tokens"
        "sops"
        "path"
        "preferences"
        "nx-config"
        "homebrew"
        "profile"
      ];
      desktop = [
        "desktop"
        "terminal"
      ];
      system = [ "dummy-files" ];
      theme = [ "theme-home" ];
    };
  };
}
