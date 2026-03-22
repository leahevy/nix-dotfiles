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
  name = "poetry";

  group = "dev";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        poetry
      ];
    };
  };
}
