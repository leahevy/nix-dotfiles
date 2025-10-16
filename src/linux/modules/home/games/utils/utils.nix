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
  name = "utils";

  group = "games";
  input = "linux";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        jstest-gtk
        evtest
        linuxConsoleTools
        SDL2
      ];
    };
}
