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
  name = "blink-indent";

  group = "nvim-modules";
  input = "common";

  settings = {
    enableOnStart = true;
    omitWhitespaceCharacter = true;
    patchScopePartial = true;

    excludeFiletypes = [
      "undotree"
      "diff"
      "help"
      "dashboard"
      "toggleterm"
      "NvimTree"
      "telescope"
      "lspinfo"
      "checkhealth"
      "man"
      "qf"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "startify"
      "alpha"
      "neo-tree"
      "Trouble"
      "trouble"
      "lazy"
      "mason"
      "notify"
      "popup"
      "qf"
      "yazi"
      "dapui_scopes"
      "dapui_breakpoints"
      "dapui_stacks"
      "dapui_watches"
      "dapui-repl"
      "dapui_console"
      "dap-repl"
      "OverseerList"
      "neotest-output-panel"
      "neotest-summary"
      ""
    ];

    colors = {
      static = null;
      color1 = null;
      color2 = null;
      color3 = null;
      color4 = null;
      color5 = null;
      color6 = null;
      color7 = null;
    };
  };

  module = {
    home =
      config:
      let
        theme = config.nx.preferences.theme;
        colors = {
          static =
            if self.settings.colors.static != null then
              self.settings.colors.static
            else
              theme.colors.separators.veryDark.html;
          color1 =
            if self.settings.colors.color1 != null then
              self.settings.colors.color1
            else
              theme.colors.main.base.green.html;
          color2 =
            if self.settings.colors.color2 != null then
              self.settings.colors.color2
            else
              theme.colors.main.base.orange.html;
          color3 =
            if self.settings.colors.color3 != null then
              self.settings.colors.color3
            else
              theme.colors.main.base.yellow.html;
          color4 =
            if self.settings.colors.color4 != null then
              self.settings.colors.color4
            else
              theme.colors.main.base.cyan.html;
          color5 =
            if self.settings.colors.color5 != null then
              self.settings.colors.color5
            else
              theme.colors.main.base.purple.html;
          color6 =
            if self.settings.colors.color6 != null then
              self.settings.colors.color6
            else
              theme.colors.main.base.pink.html;
          color7 =
            if self.settings.colors.color7 != null then
              self.settings.colors.color7
            else
              theme.colors.main.base.red.html;
        };
      in
      {
        programs.nixvim = {
          extraPlugins = [
            (pkgs.vimUtils.buildVimPlugin {
              name = "blink-indent";
              src = pkgs.fetchFromGitHub {
                owner = "saghen";
                repo = "blink.indent";
                rev = "93ff30292d34116444ff9db5264f6ccd34f3f71f";
                hash = "sha256-aPCJAK/hO/Vn8kiYyoaMdJjO6b3ce1IXo8Xy4LJS+q8=";
              };
            })
          ];

          keymaps = [
            {
              mode = "n";
              key = "<leader>Xi";
              action = "<cmd>lua _G.toggle_blink_indent()<CR>";
              options = {
                desc = "Toggle indent guides";
                silent = true;
              };
            }
          ];

          plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
            {
              __unkeyed-1 = "<leader>Xi";
              desc = "Toggle indent guides";
              icon = "🪜";
            }
          ];

          extraConfigLua = ''
            _G.nx_modules = _G.nx_modules or {}
            _G.nx_modules["45-blink-indent"] = function()
              require('blink.indent').setup({
                blocked = {
                  buftypes = { include_defaults = true },
                  filetypes = { include_defaults = true, ${
                    lib.concatMapStringsSep ", " (ft: "'${ft}'") self.settings.excludeFiletypes
                  } },
                },
                static = {
                  enabled = true,
                  char = '┊',
                  priority = 1,
                  highlights = { 'BlinkIndent' },${lib.optionalString self.settings.omitWhitespaceCharacter ''whitespace_char = " ",''}
                },
                scope = {
                  enabled = true,
                  char = '┊',
                  priority = 1000,
                  highlights = { 'BlinkIndentRed', 'BlinkIndentOrange', 'BlinkIndentYellow', 'BlinkIndentGreen', 'BlinkIndentViolet', 'BlinkIndentCyan', 'BlinkIndentBlue' },
                  underline = {
                    enabled = false,
                    highlights = { 'BlinkIndentRedUnderline', 'BlinkIndentOrangeUnderline', 'BlinkIndentYellowUnderline', 'BlinkIndentGreenUnderline', 'BlinkIndentVioletUnderline', 'BlinkIndentCyanUnderline', 'BlinkIndentBlueUnderline' },
                  },
                },
              })

              vim.api.nvim_set_hl(0, "BlinkIndent", { fg = "${colors.static}" })
              vim.api.nvim_set_hl(0, "BlinkIndentScope", { fg = "${colors.color7}" })

              vim.api.nvim_set_hl(0, "BlinkIndentRed", { fg = "${colors.color1}" })
              vim.api.nvim_set_hl(0, "BlinkIndentOrange", { fg = "${colors.color2}" })
              vim.api.nvim_set_hl(0, "BlinkIndentYellow", { fg = "${colors.color3}" })
              vim.api.nvim_set_hl(0, "BlinkIndentGreen", { fg = "${colors.color4}" })
              vim.api.nvim_set_hl(0, "BlinkIndentViolet", { fg = "${colors.color5}" })
              vim.api.nvim_set_hl(0, "BlinkIndentCyan", { fg = "${colors.color6}" })
              vim.api.nvim_set_hl(0, "BlinkIndentBlue", { fg = "${colors.color7}" })

              vim.api.nvim_set_hl(0, "BlinkIndentRedUnderline", { fg = "${colors.color1}", underline = true })
              vim.api.nvim_set_hl(0, "BlinkIndentOrangeUnderline", { fg = "${colors.color2}", underline = true })
              vim.api.nvim_set_hl(0, "BlinkIndentYellowUnderline", { fg = "${colors.color3}", underline = true })
              vim.api.nvim_set_hl(0, "BlinkIndentGreenUnderline", { fg = "${colors.color4}", underline = true })
              vim.api.nvim_set_hl(0, "BlinkIndentVioletUnderline", { fg = "${colors.color5}", underline = true })
              vim.api.nvim_set_hl(0, "BlinkIndentCyanUnderline", { fg = "${colors.color6}", underline = true })
              vim.api.nvim_set_hl(0, "BlinkIndentBlueUnderline", { fg = "${colors.color7}", underline = true })

              vim.g.indent_guide = ${if self.settings.enableOnStart then "true" else "false"}

              local parser_scope = require('blink.indent.parser.scope')
              local parser = require('blink.indent.parser')

              if parser_scope and parser_scope.get_scope_start then
                local original_get_scope_start = parser_scope.get_scope_start
                parser_scope.get_scope_start = function(bufnr, cursor_line, shiftwidth)
                  local line, scope_level = original_get_scope_start(bufnr, cursor_line, shiftwidth)

                  if scope_level and scope_level ~= nil then
                    vim.api.nvim_buf_set_var(bufnr, 'blink_indent_scope_level', scope_level)
                  else
                    vim.api.nvim_buf_set_var(bufnr, 'blink_indent_scope_level', 0)
                  end

                  return line, scope_level
                end

                ${lib.optionalString self.settings.patchScopePartial ''
                  local patched_get_scope_partial = function(bufnr, winnr, indent_levels, range)
                    local cursor_line = vim.api.nvim_win_get_cursor(winnr)[1]
                    local scope_search_start_line, scope_indent_level = parser_scope.get_scope_start(bufnr, cursor_line, require('blink.indent.utils').get_shiftwidth(bufnr))

                    scope_indent_level = scope_indent_level or 0
                    scope_search_start_line = scope_search_start_line or cursor_line

                    local scope_start_line = scope_search_start_line
                    while scope_start_line > range.start_line do
                      local prev_indent = indent_levels[scope_start_line - 1] or 0
                      if scope_indent_level > prev_indent then break end
                      scope_start_line = scope_start_line - 1
                    end
                    local scope_end_line = scope_search_start_line
                    while scope_end_line < range.end_line do
                      local next_indent = indent_levels[scope_end_line + 1] or 0
                      if scope_indent_level > next_indent then break end
                      scope_end_line = scope_end_line + 1
                    end

                    return { indent_level = scope_indent_level, start_line = scope_start_line, end_line = scope_end_line }
                  end

                  parser_scope.get_scope_partial = patched_get_scope_partial
                  parser.get_scope_partial = patched_get_scope_partial
                ''}
              end

              function _G.toggle_blink_indent()
                vim.g.indent_guide = not vim.g.indent_guide
                require('blink.indent').enable(vim.g.indent_guide)

                local status = vim.g.indent_guide and "enabled" or "disabled"
                local icon = vim.g.indent_guide and "✅" or "❌"
                vim.notify("Feature " .. status, vim.log.levels.INFO, {
                  icon = icon,
                  title = "Blink Indent"
                })
              end
            end
          '';
        };
      };
  };
}
