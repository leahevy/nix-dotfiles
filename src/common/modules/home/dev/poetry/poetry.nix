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
  name = "poetry";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        poetry
      ];
    };
}
