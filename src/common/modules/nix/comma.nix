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
  name = "comma";

  group = "nix";
  input = "common";

  module = {
    home = config: {
      home = {
        packages = with pkgs; [
          comma
        ];
      };
    };
  };
}
