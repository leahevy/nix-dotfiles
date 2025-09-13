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
  name = "gc";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nh = {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 4d --keep 3";
      };

      # Old config not using nh
      #
      #   nix = {
      #     gc = {
      #       automatic = true;
      #       dates = "19:00";
      #       options = "--delete-older-than 30d";
      #       persistent = true;
      #       randomizedDelaySec = "15min";
      #     };
      #   };
    };
}
