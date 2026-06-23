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
  name = "latex";

  group = "text";
  input = "common";

  module = {
    home = config: {
      programs.texlive = {
        enable = true;
      };

      programs.pandoc = {
        enable = true;
      };
    };
  };
}
