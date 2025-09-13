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
  name = "cmake";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        cmake
      ];
    };
}
