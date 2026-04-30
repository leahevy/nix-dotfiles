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

  submodules = { };
}
