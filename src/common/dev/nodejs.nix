args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "nodejs";

  group = "dev";
  input = "common";

  options = {
    additionalPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Node.js packages to install alongside nodejs and yarn.";
    };
  };

  module = {
    home =
      { config, additionalPackages, ... }:
      {
        home.packages =
          with pkgs;
          [
            (lib.lowPrio nodejs)
            yarn
          ]
          ++ additionalPackages;

        home.persistence."${self.persist}" = {
          directories = [
            ".npm"
          ];
        };
      };
  };
}
