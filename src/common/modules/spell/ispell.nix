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

  group = "spell";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        ispell
      ];
    };
}
