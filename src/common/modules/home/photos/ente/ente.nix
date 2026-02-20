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
  name = "ente";

  group = "photos";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        ente-desktop
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/ente"
        ];
      };
    };
}
