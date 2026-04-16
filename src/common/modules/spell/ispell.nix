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
  name = "ispell";

  group = "spell";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        ispell
      ];
    };
  };
}
