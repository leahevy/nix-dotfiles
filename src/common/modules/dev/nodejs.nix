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
    let
      minPackages = [ "npm" ];
      combinedPackages = self.settings.basePackages ++ self.settings.additionalPackages;
    in
    {
      home.packages =
        with pkgs;
        [
          (lib.lowPrio nodejs)
          yarn
        ]
        ++ lib.optionals (combinedPackages != minPackages) (
          map (pkg: pkgs.nodePackages.${pkg}) (combinedPackages)
        );

      home.persistence."${self.persist}" = {
        directories = [
          ".npm"
        ];
      };
    };
}
