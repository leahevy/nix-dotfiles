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

  group = "nvim-modules";
  input = "common";

  module = {
    home = config: {
      programs.nixvim = {
        plugins.tmux-navigator = {
          enable = true;
        };
      };
    };
  };
}
