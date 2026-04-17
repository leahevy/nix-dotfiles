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
  name = "command-not-found";

  group = "shell";
  input = "common";

  module = {
    home = config: {
      programs = {
        command-not-found = {
          enable = true;
        };
      };
    };
  };
}
