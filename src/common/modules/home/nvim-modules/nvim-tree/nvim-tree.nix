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
      programs.nixvim.extraConfigLua = ''
        _G.nx_modules = _G.nx_modules or {}
        _G.nx_modules["80-config-nvim-tree"] = function()
          require("nvim-tree").setup({
            disable_netrw = false,
            hijack_netrw = false,
          })

          vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
            callback = function()
              vim.defer_fn(function()
                vim.api.nvim_set_hl(0, "NvimTreeNormal", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
                vim.api.nvim_set_hl(0, "NvimTreeNormalNC", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
                vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
                vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}", fg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
                vim.api.nvim_set_hl(0, "NvimTreeVertSplit", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}", fg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
              end, 100)
            end,
          })
        end
      '';

      programs.nixvim.extraPlugins = with pkgs.vimPlugins; [
        nvim-tree-lua
      ];

      programs.nixvim.keymaps = [
        {
          mode = "n";
          key = "<leader>t";
          action.__raw = ''
            function()
              if vim.bo.filetype == "NvimTree" then
                vim.cmd.NvimTreeClose()
              else
                vim.cmd.NvimTreeFocus()
              end
            end
          '';
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
