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
  name = "discord";

  group = "chat";
  input = "common";

  unfree = [
    "discord"
  ];

  module = {
    home = config: {
      programs.discord = {
        enable = true;
        package = pkgs.discord;
        settings = {
          SKIP_HOST_UPDATE = true;
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/discord"
        ];
      };
    };
  };
}
