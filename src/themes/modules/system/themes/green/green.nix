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
  name = "green";
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
