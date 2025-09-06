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
  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = with pkgs-unstable; [
          claude-code
        ];
      };
    };
}
