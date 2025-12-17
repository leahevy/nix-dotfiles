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

  settings = {
    activeTabColor = self.theme.colors.blocks.primary.foreground.html;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.extraConfigLua = ''
        _G.nx_modules = _G.nx_modules or {}
        _G.nx_modules["99-transparency"] = function()
          local function set_transparent_bg()
            vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
            vim.api.nvim_set_hl(0, "SignColumn", { bg = "none" })
            vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none", fg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })

            vim.api.nvim_set_hl(0, "LineNr", { bg = "none", fg = "${self.theme.colors.separators.normal.html}" })
            vim.api.nvim_set_hl(0, "LineNrAbove", { bg = "none", fg = "${self.theme.colors.separators.normal.html}" })
            vim.api.nvim_set_hl(0, "LineNrBelow", { bg = "none", fg = "${self.theme.colors.separators.normal.html}" })
            local cursor_line_nr = vim.api.nvim_get_hl(0, { name = "CursorLineNr" })
            if not cursor_line_nr.fg then
              cursor_line_nr.fg = "${self.theme.colors.blocks.primary.foreground.html}"
              cursor_line_nr.bold = true
            end
            vim.api.nvim_set_hl(0, "CursorLineNr", vim.tbl_extend("force", cursor_line_nr, { bg = "none" }))

            vim.api.nvim_set_hl(0, "TabLine", { bg = "none" })
            vim.api.nvim_set_hl(0, "TabLineFill", { bg = "none" })
            vim.api.nvim_set_hl(0, "TabLineSel", { bg = "none", fg = "${self.settings.activeTabColor}", bold = true })

            ${lib.optionalString (self.isModuleEnabled "nvim-modules.gitgutter") ''
              local gitgutter_add = vim.api.nvim_get_hl(0, { name = "GitGutterAdd" })
              local gitgutter_change = vim.api.nvim_get_hl(0, { name = "GitGutterChange" })
              local gitgutter_delete = vim.api.nvim_get_hl(0, { name = "GitGutterDelete" })
              local gitgutter_changeDelete = vim.api.nvim_get_hl(0, { name = "GitGutterChangeDelete" })

              vim.api.nvim_set_hl(0, "GitGutterAdd", { bg = "none", fg = gitgutter_add.fg })
              vim.api.nvim_set_hl(0, "GitGutterChange", { bg = "none", fg = gitgutter_change.fg })
              vim.api.nvim_set_hl(0, "GitGutterDelete", { bg = "none", fg = gitgutter_delete.fg })
              vim.api.nvim_set_hl(0, "GitGutterChangeDelete", { bg = "none", fg = gitgutter_changeDelete.fg })
            ''}

            ${lib.optionalString (self.isModuleEnabled "nvim-modules.gitsigns") ''
              local gitsigns_add = vim.api.nvim_get_hl(0, { name = "GitSignsAdd" })
              local gitsigns_change = vim.api.nvim_get_hl(0, { name = "GitSignsChange" })
              local gitsigns_delete = vim.api.nvim_get_hl(0, { name = "GitSignsDelete" })
              local gitsigns_topdelete = vim.api.nvim_get_hl(0, { name = "GitSignsTopdelete" })
              local gitsigns_changedelete = vim.api.nvim_get_hl(0, { name = "GitSignsChangedelete" })
              local gitsigns_untracked = vim.api.nvim_get_hl(0, { name = "GitSignsUntracked" })

              vim.api.nvim_set_hl(0, "GitSignsAdd", { bg = "none", fg = gitsigns_add.fg })
              vim.api.nvim_set_hl(0, "GitSignsChange", { bg = "none", fg = gitsigns_change.fg })
              vim.api.nvim_set_hl(0, "GitSignsDelete", { bg = "none", fg = gitsigns_delete.fg })
              vim.api.nvim_set_hl(0, "GitSignsTopdelete", { bg = "none", fg = gitsigns_topdelete.fg })
              vim.api.nvim_set_hl(0, "GitSignsChangedelete", { bg = "none", fg = gitsigns_changedelete.fg })
              vim.api.nvim_set_hl(0, "GitSignsUntracked", { bg = "none", fg = gitsigns_untracked.fg })

              local gitsigns_staged_add = vim.api.nvim_get_hl(0, { name = "GitSignsStagedAdd" })
              local gitsigns_staged_change = vim.api.nvim_get_hl(0, { name = "GitSignsStagedChange" })
              local gitsigns_staged_delete = vim.api.nvim_get_hl(0, { name = "GitSignsStagedDelete" })
              local gitsigns_staged_topdelete = vim.api.nvim_get_hl(0, { name = "GitSignsStagedTopdelete" })
              local gitsigns_staged_changedelete = vim.api.nvim_get_hl(0, { name = "GitSignsStagedChangedelete" })
              local gitsigns_staged_untracked = vim.api.nvim_get_hl(0, { name = "GitSignsStagedUntracked" })

              vim.api.nvim_set_hl(0, "GitSignsStagedAdd", { bg = "none", fg = gitsigns_staged_add.fg })
              vim.api.nvim_set_hl(0, "GitSignsStagedChange", { bg = "none", fg = gitsigns_staged_change.fg })
              vim.api.nvim_set_hl(0, "GitSignsStagedDelete", { bg = "none", fg = gitsigns_staged_delete.fg })
              vim.api.nvim_set_hl(0, "GitSignsStagedTopdelete", { bg = "none", fg = gitsigns_staged_topdelete.fg })
              vim.api.nvim_set_hl(0, "GitSignsStagedChangedelete", { bg = "none", fg = gitsigns_staged_changedelete.fg })
              vim.api.nvim_set_hl(0, "GitSignsStagedUntracked", { bg = "none", fg = gitsigns_staged_untracked.fg })
            ''}

            vim.opt.pumblend = 0
            vim.opt.winblend = 0
          end

          vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme", "BufNew", "BufNewFile", "BufAdd", "WinNew"}, {
            callback = function()
              vim.defer_fn(set_transparent_bg, 100)
            end,
          })
        end
      '';
    };
}
