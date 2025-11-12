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
  name = "gitgutter";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.gitgutter = {
          enable = true;
          settings = {
            map_keys = false;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>gp";
            action = ":GitGutterPreviewHunk<CR>";
            options = {
              silent = true;
              desc = "Preview hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gs";
            action = ":GitGutterStageHunk | lua vim.notify('✅ Git hunk staged', vim.log.levels.INFO, { title = 'Git' })<CR>";
            options = {
              silent = true;
              desc = "Stage hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gu";
            action = ":GitGutterUndoHunk | lua vim.notify('↩️ Git hunk undone', vim.log.levels.INFO, { title = 'Git' })<CR>";
            options = {
              silent = true;
              desc = "Undo hunk";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
            icon = "⇡";
          }
          {
            __unkeyed-1 = "<leader>gp";
            desc = "Preview hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "<leader>gs";
            desc = "Stage hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "<leader>gu";
            desc = "Undo hunk";
            icon = "󰐕";
          }
        ];
      };

      home.file.".config/nvim-init/99-gitgutter.lua".text = ''
        local function set_gitgutter_colors()
          vim.api.nvim_set_hl(0, "GitGutterAdd", { fg = "#55ff55" })
          vim.api.nvim_set_hl(0, "GitGutterChange", { fg = "#ffff66" })
          vim.api.nvim_set_hl(0, "GitGutterDelete", { fg = "#ff0099" })
          vim.api.nvim_set_hl(0, "GitGutterChangeDelete", { fg = "#00ddff" })
        end

        vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
          callback = function()
            vim.defer_fn(set_gitgutter_colors, 100)
          end,
        })
      '';
    };
}
