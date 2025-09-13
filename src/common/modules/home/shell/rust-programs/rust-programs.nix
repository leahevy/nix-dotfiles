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
  name = "rust-programs";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        bat
        fd
        ripgrep
      ];
    };
}
