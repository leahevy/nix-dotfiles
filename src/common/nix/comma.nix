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
      programs.nix-index-database.comma.enable = true;
    };
  };
}
