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

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        zstd
        zip
        unzip
        p7zip
        gnutar
      ];
    };
}
