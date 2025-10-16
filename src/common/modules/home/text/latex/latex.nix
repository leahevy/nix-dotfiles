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

  group = "text";
  input = "common";
  namespace = "home";

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
