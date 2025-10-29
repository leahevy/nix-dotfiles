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

  settings = {
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

        globals = {
          "airline#extensions#tabline#enabled" = 1;
          "airline#extensions#tabline#show_close_button" = 0;
        };
      };
    };
}
