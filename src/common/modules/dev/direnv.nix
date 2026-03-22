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
  name = "direnv";

  group = "dev";
  input = "common";

  on = {
    home = config: {
      programs = {
        direnv = {
          enable = true;
        };
      };
    };
  };
}
