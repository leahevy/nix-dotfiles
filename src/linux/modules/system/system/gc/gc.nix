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

  group = "system";
  input = "linux";
  namespace = "system";

  defaults = {
    useNH = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nh = lib.mkIf self.settings.useNH {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 4d --keep 3";
      };

      nix = lib.mkIf (!self.settings.useNH) {
        gc = {
          automatic = true;
          dates = "19:00";
          options = "--delete-older-than 30d";
          persistent = true;
          randomizedDelaySec = "15min";
        };
      };
    };
}
