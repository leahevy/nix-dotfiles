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
  name = "direnv";

  configuration =
    context@{ config, options, ... }:
    {
      programs = {
        direnv = {
          enable = true;
        };
      };
    };
}
