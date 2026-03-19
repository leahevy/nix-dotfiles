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
  name = "searchbox";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          searchbox-nvim
          nui-nvim
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>s";
            group = "Search";
            icon = "🔍";
          }
          {
            __unkeyed-1 = "<leader>ss";
            desc = "Search forward";
            icon = "→";
          }
          {
            __unkeyed-1 = "<leader>sS";
            desc = "Search reverse";
            icon = "←";
          }
          {
            __unkeyed-1 = "<leader>sr";
            desc = "Search and replace";
            icon = "🔄";
          }
          {
            __unkeyed-1 = "<leader>sR";
            desc = "Replace word under cursor";
            icon = "📝";
          }
          {
            __unkeyed-1 = "<leader>sc";
            desc = "Search and highlight all";
            icon = "✨";
          }
          {
            __unkeyed-1 = "<leader>sC";
            desc = "Highlight word under cursor";
            icon = "🎯";
          }
          {
            __unkeyed-1 = "<leader>sq";
            desc = "Clear all highlights";
            icon = "🧹";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["90-searchbox"] = function()
            require('searchbox').setup({
              defaults = {
                reverse = false,
                exact = false,
                prompt = ' ',
                modifier = 'plain',
                confirm = 'off',
                clear_matches = true,
                show_matches = false,
              },
              popup = {
                relative = 'win',
                position = {
                  row = '5%',
                  col = '95%',
                },
                size = 30,
                border = {
                  style = 'rounded',
                  text = {
                    top = ' Search ',
                    top_align = 'center',
                  },
                },
                win_options = {
                  winhighlight = 'Normal:Normal,FloatBorder:FloatBorder',
                },
              },
            })

            local opts = { noremap = true, silent = true }

            vim.keymap.set('n', '<leader>ss', ':SearchBoxIncSearch<CR>', { desc = 'Search forward', unpack(opts) })
            vim.keymap.set('n', '<leader>sS', ':SearchBoxIncSearch reverse=true<CR>', { desc = 'Search reverse', unpack(opts) })
            vim.keymap.set('n', '<leader>sr', ':SearchBoxReplace<CR>', { desc = 'Search and replace', unpack(opts) })
            vim.keymap.set('n', '<leader>sR', ':SearchBoxReplace -- <C-r>=expand("<cword>")<CR><CR>', { desc = 'Replace word under cursor', unpack(opts) })
            vim.keymap.set('n', '<leader>sc', ':SearchBoxMatchAll clear_matches=false<CR>', { desc = 'Search and highlight all', unpack(opts) })
            vim.keymap.set('n', '<leader>sC', ':SearchBoxMatchAll clear_matches=false exact=true -- <C-r>=expand("<cword>")<CR><CR>', { desc = 'Highlight word under cursor', unpack(opts) })
            vim.keymap.set('n', '<leader>sq', function()
              vim.cmd('SearchBoxClear')
              vim.cmd('nohlsearch')
              vim.notify('Search highlights cleared', vim.log.levels.INFO, {
                icon = '🧹',
                title = 'Search'
              })
            end, { desc = 'Clear all highlights', unpack(opts) })
          end
        '';
      };
    };
}
