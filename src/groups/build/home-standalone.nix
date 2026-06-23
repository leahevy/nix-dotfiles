args@{
  lib,
  pkgs,
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
      core = [ "darwin" ];
    };
  };
}
