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
  name = "archive-tools";

  group = "utils";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        zstd
        zip
        unzip
        p7zip
        gnutar
      ];
    };
  };
}
