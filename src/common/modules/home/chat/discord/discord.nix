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
  name = "discord";

  unfree = [
    "discord"
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        discord
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/discord"
        ];
      };
    };
}
