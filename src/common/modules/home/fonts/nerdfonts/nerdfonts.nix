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
  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        nerd-fonts.droid-sans-mono
        nerd-fonts.ubuntu
        nerd-fonts.ubuntu-mono
        nerd-fonts.ubuntu-sans
        powerline-fonts
      ];
    };
}
