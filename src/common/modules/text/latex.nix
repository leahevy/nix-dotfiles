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
  name = "latex";

  group = "text";
  input = "common";

  on = {
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
