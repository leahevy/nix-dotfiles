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
  name = "poetry";

  group = "dev";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        poetry
      ];
    };
  };
}
