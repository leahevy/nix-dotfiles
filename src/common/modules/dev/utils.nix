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
  name = "utils";

  group = "dev";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        socat
      ];
    };
}
