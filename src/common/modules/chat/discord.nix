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

  on = {
    home = config: {
      home.packages = with pkgs; [
        discord
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/discord"
        ];
      };
    };
  };
}
