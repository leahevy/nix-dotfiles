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
  name = "vim-airline";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  defaults = {
    powerlineSymbols = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.airline = {
          enable = true;
          settings = {
            powerline_fonts = lib.mkIf self.settings.powerlineSymbols 1;
            skip_empty_sections = 1;
          };
        };
      };
    };
}
