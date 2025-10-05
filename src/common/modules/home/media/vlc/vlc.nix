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
  name = "vlc";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        vlc
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/vlc"
          ".local/share/vlc"
        ];
      };
    };
}
