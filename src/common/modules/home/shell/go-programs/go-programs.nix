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
  name = "go-programs";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        fzf
      ];
    };
}
