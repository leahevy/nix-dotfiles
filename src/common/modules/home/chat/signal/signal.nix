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
  name = "signal";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        signal-desktop
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Signal"
        ];
      };
    };
}
