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
  name = "vim-tmux-navigator";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.tmux-navigator = {
          enable = true;
        };
      };
    };
}
