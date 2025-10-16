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
  name = "spotify";

  group = "music";
  input = "linux";
  namespace = "home";

  unfree = [ "spotify" ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        spotify
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/spotify"
          ".cache/spotify"
        ];
      };
    };
}
