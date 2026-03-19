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

  group = "fonts";
  input = "common";
  namespace = "home";

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
        nerd-fonts.dejavu-sans-mono
        nerd-fonts.ubuntu
      ];
    };
}
