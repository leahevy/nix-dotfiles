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
      programs.nixvim.extraConfigLua = ''
        _G.nx_modules = _G.nx_modules or {}
        _G.nx_modules["40-jk-escape"] = function()
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
        end
      '';
    };
}
