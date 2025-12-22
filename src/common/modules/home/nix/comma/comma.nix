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
  name = "comma";

  group = "nix";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = with pkgs; [
          comma
        ];
      };
    };
}
