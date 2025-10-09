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
  name = "telescope";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.telescope = {
          enable = true;
          extensions = {
            fzf-native = {
              enable = true;
            };
          };
          keymaps = {
            "<leader>ff" = {
              action = "find_files";
              options.desc = "Find all files";
            };
            "<leader>fh" = {
              action = "help_tags";
              options.desc = "Help tags";
            };
            "<leader>fr" = {
              action = "oldfiles";
              options.desc = "Recent files";
            };
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader><leader>";
            action = "<cmd>lua local git_root = _G.find_git_root(); if git_root then require('telescope.builtin').git_files() else require('telescope.builtin').find_files() end<CR>";
            options = {
              silent = true;
              desc = "Find files";
            };
          }
          {
            mode = "n";
            key = "<leader>/";
            action = "<cmd>Telescope live_grep<CR>";
            options = {
              silent = true;
              desc = "Search in project";
            };
          }
          {
            mode = "n";
            key = "<leader>b";
            action = "<cmd>Telescope buffers<CR>";
            options = {
              silent = true;
              desc = "Switch buffers";
            };
          }
        ];
      };

      home.file.".config/nvim-init/50-telescope-project.lua".text = ''
        local function find_git_root(path)
          local current = path or vim.fn.expand('%:p:h')
          while current and current ~= '/' do
            if vim.fn.isdirectory(current .. '/.git') == 1 then
              return current
            end
            current = vim.fn.fnamemodify(current, ':h')
          end
          return nil
        end

        _G.find_git_root = find_git_root

        vim.api.nvim_create_user_command('ProjectFiles', function()
          local git_root = find_git_root() or vim.fn.getcwd()
          require('telescope.builtin').find_files({ cwd = git_root })
        end, {})

        vim.api.nvim_create_user_command('ProjectGrep', function(opts)
          local git_root = find_git_root() or vim.fn.getcwd()
          if opts.args and opts.args ~= "" then
            require('telescope.builtin').grep_string({ search = opts.args, cwd = git_root })
          else
            require('telescope.builtin').live_grep({ cwd = git_root })
          end
        end, { nargs = '?' })
      '';

      home.packages = with pkgs; [
        fzf
        ripgrep
        fd
      ];
    };
}
