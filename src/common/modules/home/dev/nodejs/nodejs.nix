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
  name = "nodejs";

  group = "dev";
  input = "common";
  namespace = "home";

  settings = {
    basePackages = [
      "npm"
    ];
    additionalPackages = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages =
        with pkgs;
        [
          (lib.lowPrio nodejs)
          yarn
        ]
        ++ (map (pkg: pkgs.nodePackages.${pkg}) (
          self.settings.basePackages ++ self.settings.additionalPackages
        ));

      home.persistence."${self.persist}" = {
        directories = [
          ".npm"
        ];
      };
    };
}
