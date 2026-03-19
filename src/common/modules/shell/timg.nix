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

  group = "shell";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        timg
      ];
    };
}
