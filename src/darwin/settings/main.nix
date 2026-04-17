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
  name = "main";

  group = "settings";
  input = "darwin";

  module = {
    darwin.home = config: {
      programs.nix-plist-manager = {
        enable = true;
      };
    };
  };
}
