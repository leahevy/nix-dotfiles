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
  name = "cmake";

  group = "dev";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        cmake
      ];
    };
  };
}
