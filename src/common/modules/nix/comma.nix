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

  on = {
    home = config: {
      home = {
        packages = with pkgs; [
          comma
        ];
      };
    };
  };
}
