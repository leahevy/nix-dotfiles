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
  name = "beeper";

  unfree = [ "beeper" ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        beeper
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/BeeperTexts" ];
      };
    };
}
