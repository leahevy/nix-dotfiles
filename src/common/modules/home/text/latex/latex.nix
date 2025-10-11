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
  name = "latex";

  configuration =
    context@{ config, options, ... }:
    {
      programs.texlive = {
        enable = true;
      };

      programs.pandoc = {
        enable = true;
      };
    };
}
