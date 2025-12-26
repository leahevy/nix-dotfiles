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

  group = "media";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
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
