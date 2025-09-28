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
  name = "ghostty";

  submodules = {
    common = {
      terminal = {
        ghostty-config = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.ghostty.package = lib.mkForce pkgs-unstable.ghostty;
    };
}
