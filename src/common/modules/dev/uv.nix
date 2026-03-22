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
  name = "uv";

  group = "dev";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        uv
      ];
    };
  };
}
