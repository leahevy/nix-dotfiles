args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "lutris";

  group = "games";
  input = "linux";

  submodules = {
    linux = {
      games = {
        heroic = true;
      };
    };
  };

  module = {
    home = config: {
      home.packages = with pkgs; [
        lutris
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/lutris"
          ".cache/lutris"
        ];
      };
    };
  };
}
