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
  name = "cmake";

  group = "dev";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        cmake
      ];
    };
  };
}
