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
  name = "nix-index";

  configuration =
    context@{ config, options, ... }:
    {
      programs = {
        nix-index.enable = true;
      };

      programs = {
        command-not-found = {
          enable = lib.mkForce false;
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".cache/nix-index"
        ];
      };
    };
}
