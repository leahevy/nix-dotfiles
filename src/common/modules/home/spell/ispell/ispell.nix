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
  name = "ispell";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        ispell
      ];
    };
}
