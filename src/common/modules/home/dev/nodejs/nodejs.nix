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

  defaults = {
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
          nodejs
          yarn
        ]
        ++ (map (pkg: pkgs.nodePackages.${pkg}) (
          self.settings.basePackages ++ self.settings.additionalPackages
        ));
    };
}
