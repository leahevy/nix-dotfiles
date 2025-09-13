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

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-ld.enable = true;
    };
}
