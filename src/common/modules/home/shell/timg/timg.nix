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
  name = "timg";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        timg
      ];
    };
}
