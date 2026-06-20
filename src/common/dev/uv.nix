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
  name = "uv";

  group = "dev";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        uv
      ];
    };
  };
}
