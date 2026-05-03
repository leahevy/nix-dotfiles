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

  disableOnTestingVM = true;

  module = {
    system = config: {
      programs.nix-ld.enable = true;
    };
  };
}
