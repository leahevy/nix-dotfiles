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
  name = "nix-ld";
  group = "core";
  input = "build";

  on = {
    system = config: {
      programs.nix-ld.enable = true;
    };
  };
}
