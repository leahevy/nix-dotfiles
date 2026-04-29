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
  name = "just";

  group = "dev";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        just
      ];
    };
  };
}
