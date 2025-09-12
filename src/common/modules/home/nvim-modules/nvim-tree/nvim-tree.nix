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
  meta = {
    name = "nvim-tree";
    description = "File explorer for Neovim (with netrw coexistence)";
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/80-config-nvim-tree.lua".text = ''
        require("nvim-tree").setup({
          disable_netrw = false,
          hijack_netrw = false,
        })
      '';

      programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
        nvim-tree-lua
      ];
    };
}
