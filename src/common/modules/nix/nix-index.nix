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

  group = "nix";
  input = "common";

  module = {
    home = config: {
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
  };
}
