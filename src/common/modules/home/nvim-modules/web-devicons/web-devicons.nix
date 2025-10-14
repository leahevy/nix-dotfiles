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
  name = "web-devicons";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.web-devicons = {
        enable = true;
      };
    };
}
