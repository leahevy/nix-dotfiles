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
  name = "transparency";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  defaults = {
    activeTabColor = "#50fa7b";
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/99-transparency.lua".text = ''
        local function set_transparent_bg()
          vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
          vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })

          vim.api.nvim_set_hl(0, "LineNr", { bg = "none" })
          vim.api.nvim_set_hl(0, "LineNrAbove", { bg = "none" })
          vim.api.nvim_set_hl(0, "LineNrBelow", { bg = "none" })
          vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "none" })

          vim.api.nvim_set_hl(0, "TabLine", { bg = "none" })
          vim.api.nvim_set_hl(0, "TabLineFill", { bg = "none" })
          vim.api.nvim_set_hl(0, "TabLineSel", { bg = "none", fg = "${self.settings.activeTabColor}", bold = true })

          vim.api.nvim_set_hl(0, "GitGutterAdd", { bg = "none" })
          vim.api.nvim_set_hl(0, "GitGutterChange", { bg = "none" })
          vim.api.nvim_set_hl(0, "GitGutterDelete", { bg = "none" })
          vim.api.nvim_set_hl(0, "GitGutterChangeDelete", { bg = "none" })

          vim.opt.pumblend = 0
          vim.opt.winblend = 0
        end

        vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
          callback = function()
            vim.defer_fn(set_transparent_bg, 100)
          end,
        })
      '';
    };
}
