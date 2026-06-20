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
  name = "theme-system";
  group = "theme";
  input = "build";

  submodules = {
    themes = {
      base = {
        base = true;
      };
    };
  };
}
