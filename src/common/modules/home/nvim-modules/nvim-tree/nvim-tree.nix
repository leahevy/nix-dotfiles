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

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/80-config-nvim-tree.lua".text = ''
        require("nvim-tree").setup({
          disable_netrw = false,
          hijack_netrw = false,
        })

        vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
          callback = function()
            vim.defer_fn(function()
              vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "#000000" })
              vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "#000000" })
              vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { bg = "#000000" })
              vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { bg = "#000000", fg = "#000000" })
              vim.api.nvim_set_hl(0, "NvimTreeVertSplit", { bg = "#000000", fg = "#000000" })
            end, 100)
          end,
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
