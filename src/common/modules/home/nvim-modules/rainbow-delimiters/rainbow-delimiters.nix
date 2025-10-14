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
  name = "rainbow-delimiters";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.rainbow-delimiters = {
        enable = true;

        strategy = {
          "" = "global";
          vim = "local";
          html = "local";
          xml = "local";
          jsx = "local";
          tsx = "local";
          vue = "local";
        };
      };
    };
}
