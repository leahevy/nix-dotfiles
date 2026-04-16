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
  name = "codex";

  group = "dev";
  input = "common";

  module = {
    home = config: {
      programs.codex = {
        enable = true;
      };

      home.persistence."${self.persist}" = {
        directories = [ ".codex" ];
      };
    };
  };
}
