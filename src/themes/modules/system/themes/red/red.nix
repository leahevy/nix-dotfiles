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
  name = "red";
  group = "themes";
  input = "themes";
  namespace = "system";

  submodules = {
    themes = {
      base = {
        base = true;
      };
    };
  };
}
