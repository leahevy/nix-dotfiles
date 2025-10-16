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
  name = "jk-escape";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/40-jk-escape.lua".text = ''
        vim.keymap.set('i', 'jk', '<Esc>', {
          noremap = true,
          silent = true,
          desc = "Exit insert mode with jk"
        })

        vim.keymap.set('i', 'kj', '<Esc>', {
          noremap = true,
          silent = true,
          desc = "Exit insert mode with kj"
        })
      '';
    };
}
