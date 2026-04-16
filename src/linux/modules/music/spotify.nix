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

  unfree = [ "spotify" ];

  module = {
    linux.home = config: {
      home.packages = with pkgs; [
        spotify
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/spotify"
          ".cache/spotify"
        ];
      };
    };
  };
}
