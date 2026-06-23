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
  name = "timg";

  group = "shell";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        timg
      ];
    };
  };
}
