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

  on = {
    linux.home = config: {
      home.packages = with pkgs; [
        spotify
      ];

      home.persistence."${self.persist.home}" = {
        directories = [
          ".config/spotify"
          ".cache/spotify"
        ];
      };
    };
  };
}
