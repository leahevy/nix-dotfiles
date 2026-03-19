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
  name = "main";

  group = "settings";
  input = "darwin";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nix-plist-manager = {
        enable = true;
      };
    };
}
