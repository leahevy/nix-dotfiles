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
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-ld.enable = true;
    };
}
