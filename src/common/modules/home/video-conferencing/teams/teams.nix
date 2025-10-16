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
  name = "teams";

  group = "video-conferencing";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        teams-for-linux
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/teams-for-linux"
        ];
      };
    };
}
