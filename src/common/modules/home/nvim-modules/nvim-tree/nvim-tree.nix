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
  name = "nvim-tree";
  description = "File explorer for Neovim (with netrw coexistence)";

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

      programs.nixvim.keymaps = [
        {
          mode = "n";
          key = "<leader>t";
          action = ":NvimTreeToggle<CR>";
          options = {
            silent = true;
            desc = "Toggle file tree";
          };
        }
      ];

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>t";
              desc = "Toggle file tree";
              mode = "v";
            }
          ];

    };
}
