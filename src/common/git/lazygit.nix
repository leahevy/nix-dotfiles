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
  name = "lazygit";

  group = "git";
  input = "common";

  module = {
    home = config: {
      programs.lazygit = {
        enable = true;
      };
    };
  };
}
