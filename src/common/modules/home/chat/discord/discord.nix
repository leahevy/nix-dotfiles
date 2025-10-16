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

  group = "chat";
  input = "common";
  namespace = "home";

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
