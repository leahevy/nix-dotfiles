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
  name = "timg";

  group = "shell";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        timg
      ];
    };
  };
}
