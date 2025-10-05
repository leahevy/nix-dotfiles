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
  name = "nerdfonts";

  submodules = {
    common = {
      fonts = {
        fontconfig = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        powerline-fonts
        powerline
        powerline-symbols
      ];
    };
}
