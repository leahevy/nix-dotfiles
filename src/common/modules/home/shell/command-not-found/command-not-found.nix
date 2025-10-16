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

  group = "shell";
  input = "common";
  namespace = "home";

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
