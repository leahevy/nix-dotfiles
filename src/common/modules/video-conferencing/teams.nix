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

  module = {
    home = config: {
      home.packages = with pkgs; [
        teams-for-linux
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/teams-for-linux"
        ];
      };
    };
  };
}
