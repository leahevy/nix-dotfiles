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

  on = {
    darwin.home = config: {
      programs.nix-plist-manager = {
        enable = true;
      };
    };
  };
}
