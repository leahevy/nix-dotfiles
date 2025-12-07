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
  name = "theme-system";
  group = "theme";
  input = "build";
  namespace = "system";

  submodules = {
    themes = {
      base = {
        base = true;
      };
    };
  };
}
