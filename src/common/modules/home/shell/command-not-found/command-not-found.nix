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
  name = "command-not-found";

  configuration =
    context@{ config, options, ... }:
    {
      programs = {
        command-not-found = {
          enable = true;
        };
      };
    };
}
