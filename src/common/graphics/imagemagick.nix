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
  name = "imagemagick";

  group = "graphics";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [ imagemagick ];
    };
  };
}
