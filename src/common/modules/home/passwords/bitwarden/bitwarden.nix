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
  name = "bitwarden";

  group = "passwords";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        bitwarden
        bitwarden-cli
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Bitwarden"
          ".config/Bitwarden CLI"
        ];
      };
    };
}
