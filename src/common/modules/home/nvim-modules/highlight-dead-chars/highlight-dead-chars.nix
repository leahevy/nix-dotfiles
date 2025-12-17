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
  name = "highlight-dead-chars";
  description = "Highlights whitespace and non-text characters in Neovim";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    whiteSpaceColor = self.theme.colors.separators.normal.html;
    eolFill = {
      enabledOnStart = true;
      char = "‧";
      currentLineChar = "┄";
      color = self.theme.colors.separators.ultraDark.html;
      currentLineColor = self.theme.colors.terminal.colors.blue.html;
      delimiterChars = " ";
      onlyFillIfAllFit = true;
      onlyShowOnCurrentLine = false;
      highlightCurrentLine = true;
    };
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
      "gitcommit"
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
      "Codewindow"
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
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        keymaps = [
          {
            mode = "n";
            key = "<leader>Xo";
            action = "<cmd>lua _G.toggle_eol_fill()<CR>";
            options = {
              desc = "Toggle EOL fill";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>Xo";
            desc = "Toggle EOL fill";
            icon = "🔲";
          }
        ];
      };

      programs.nixvim.extraConfigLua = ''
        _G.nx_modules = _G.nx_modules or {}
        _G.nx_modules["50-highlight-dead-chars"] = function()
          vim.api.nvim_set_hl(0, "Whitespace", { fg = "${self.settings.whiteSpaceColor}" })
          vim.api.nvim_set_hl(0, "NonText", { fg = "${self.settings.whiteSpaceColor}" })
          vim.api.nvim_set_hl(0, "EolFill", { fg = "${self.settings.eolFill.color}" })
          vim.api.nvim_set_hl(0, "EolFillCurrent", { fg = "${self.settings.eolFill.currentLineColor}" })

          _G.eol_fill_enabled = ${if self.settings.eolFill.enabledOnStart then "true" else "false"}
          local ns = vim.api.nvim_create_namespace('eol_fill')
          local excluded_fts = { ${
            lib.concatMapStringsSep ", " (ft: "'${ft}'") self.settings.excludeFiletypes
          } }

          local cached_ft = nil
          local excluded_ft_set = {}
          for _, ft in ipairs(excluded_fts) do
            excluded_ft_set[ft] = true
          end

          local function is_excluded_filetype()
            local ft = vim.bo.filetype
            if cached_ft ~= ft then
              cached_ft = ft
            end
            return excluded_ft_set[ft] or false
          end

          local function clear_eol_fill()
            vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
          end

          local function add_eol_fill()
            ${lib.optionalString (self.isModuleEnabled "nvim-modules.faster") ''
              if vim.b.is_bigfile then
                return
              end
            ''}
            if not _G.eol_fill_enabled or is_excluded_filetype() or vim.bo.buftype ~= "" then
              return
            end

            clear_eol_fill()

            local bufnr = vim.api.nvim_get_current_buf()
            local winnr = vim.api.nvim_get_current_win()
            local win_width = vim.api.nvim_win_get_width(winnr)
            local actual_text_width = win_width - vim.fn.getwininfo(winnr)[1].textoff

            local start_line = math.max(0, vim.fn.line('w0') - 2)
            local end_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, vim.fn.line('w$') + 1)

            local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

            for i, line_content in ipairs(lines) do
              if line_content then
                local line_nr = start_line + i - 1
                local content_width = vim.fn.strdisplaywidth(line_content)
                local dots_needed

                local listchars_offset = 0
                if vim.o.list then
                  listchars_offset = listchars_offset + 1
                end

                if content_width > actual_text_width then
                  local remaining_width = content_width % actual_text_width
                  if remaining_width == 0 then
                    dots_needed = 0
                  else
                    dots_needed = math.max(0, actual_text_width - remaining_width - listchars_offset)
                  end
                else
                  dots_needed = math.max(0, actual_text_width - content_width - listchars_offset)
                end

                local current_line = vim.api.nvim_win_get_cursor(winnr)[1] - 1
                local is_current_line = line_nr == current_line
                local is_empty_line = line_content == ""

                local skip_eol_fill = line_content == ""

                if dots_needed > 0 and not skip_eol_fill then
                  local delimiter = "${self.settings.eolFill.delimiterChars}"
                  local delimiter_width = vim.fn.strdisplaywidth(delimiter)
                  local available_space = dots_needed - delimiter_width

                  if available_space > 0 then
                    local current_line = vim.api.nvim_win_get_cursor(winnr)[1] - 1
                    local char_pattern = line_nr == current_line and "${self.settings.eolFill.currentLineChar}" or "${self.settings.eolFill.char}"
                    local pattern_width = vim.fn.strdisplaywidth(char_pattern)
                    local full_repeats = math.floor(available_space / pattern_width)
                    local remaining_space = available_space - (full_repeats * pattern_width)

                    local only_fill_if_all_fit = ${
                      if self.settings.eolFill.onlyFillIfAllFit then "true" else "false"
                    }

                    if not (only_fill_if_all_fit and full_repeats == 0) then
                      local partial_chars = ""
                      if not only_fill_if_all_fit and remaining_space > 0 then
                        partial_chars = string.sub(char_pattern, 1, remaining_space)
                      end

                      local fill_text = delimiter .. string.rep(char_pattern, full_repeats) .. partial_chars

                      local highlight_group = "EolFill"
                      local only_show_on_current_line = ${
                        if self.settings.eolFill.onlyShowOnCurrentLine then "true" else "false"
                      }

                      if line_nr == current_line then
                        ${lib.optionalString (self.isModuleEnabled "nvim-modules.blink-indent") ''
                          local blink_scope_level = vim.b[bufnr].blink_indent_scope_level
                          if blink_scope_level and blink_scope_level > 0 then
                            local blink_indent_groups = {
                              "BlinkIndentRed", "BlinkIndentOrange", "BlinkIndentYellow",
                              "BlinkIndentGreen", "BlinkIndentViolet", "BlinkIndentCyan", "BlinkIndentBlue"
                            }
                            local group_index = ((blink_scope_level - 1) % #blink_indent_groups) + 1
                            highlight_group = blink_indent_groups[group_index]
                          else
                            highlight_group = "EolFillCurrent"
                          end
                        ''}
                        ${lib.optionalString (!self.isModuleEnabled "nvim-modules.blink-indent") ''
                          highlight_group = "EolFillCurrent"
                        ''}

                        local cursor_col = vim.api.nvim_win_get_cursor(winnr)[2]
                        if line_nr == current_line and line_content == "" and cursor_col == 0 then
                          ${lib.optionalString (self.isModuleEnabled "nvim-modules.blink-indent") ''
                            local contextual_indent = 0

                            local prev_line_nr = line_nr
                            while prev_line_nr > 0 do
                              local prev_line = vim.api.nvim_buf_get_lines(bufnr, prev_line_nr - 1, prev_line_nr, false)[1]
                              if prev_line and vim.trim(prev_line) ~= "" then
                                local prev_indent = math.floor(vim.fn.indent(prev_line_nr) / vim.bo.shiftwidth)
                                contextual_indent = math.max(0, prev_indent - 1)
                                break
                              end
                              prev_line_nr = prev_line_nr - 1
                            end

                            local blink_groups = {
                              "BlinkIndentRed", "BlinkIndentOrange", "BlinkIndentYellow",
                              "BlinkIndentGreen", "BlinkIndentViolet", "BlinkIndentCyan", "BlinkIndentBlue"
                            }
                            local empty_group_index = contextual_indent > 0
                              and ((contextual_indent - 1) % #blink_groups) + 1
                              or 1
                            highlight_group = blink_groups[empty_group_index]
                          ''}
                        end
                      else
                        if only_show_on_current_line then
                          goto continue
                        end
                      end

                      vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr, -1, {
                        virt_text = {{ fill_text, highlight_group }},
                        virt_text_pos = "eol",
                        priority = 100
                      })

                      if line_nr == current_line and highlight_group ~= "EolFill" and ${
                        if self.settings.eolFill.highlightCurrentLine then "true" else "false"
                      } then
                        local hl_def = vim.api.nvim_get_hl(0, { name = highlight_group })
                        if hl_def.fg then
                          local color_hex = string.format("#%06x", hl_def.fg)
                          vim.api.nvim_set_hl(0, "CursorLine", { underdotted = true, sp = color_hex })
                        end
                      end

                      ::continue::
                    end
                  end
                end

                if is_current_line and is_empty_line and ${
                  if self.settings.eolFill.highlightCurrentLine then "true" else "false"
                } then
                  ${lib.optionalString (self.isModuleEnabled "nvim-modules.blink-indent") ''
                    local blink_scope_level = vim.b[bufnr].blink_indent_scope_level
                    if blink_scope_level and blink_scope_level > 0 then
                      local blink_indent_groups = {
                        "BlinkIndentRed", "BlinkIndentOrange", "BlinkIndentYellow",
                        "BlinkIndentGreen", "BlinkIndentViolet", "BlinkIndentCyan", "BlinkIndentBlue"
                      }
                      local group_index = ((blink_scope_level - 1) % #blink_indent_groups) + 1
                      local highlight_group = blink_indent_groups[group_index]

                      local hl_def = vim.api.nvim_get_hl(0, { name = highlight_group })
                      if hl_def.fg then
                        local color_hex = string.format("#%06x", hl_def.fg)
                        vim.api.nvim_set_hl(0, "CursorLine", { underdotted = true, sp = color_hex })
                      end
                    end
                  ''}
                  ${lib.optionalString (!self.isModuleEnabled "nvim-modules.blink-indent") ''
                    vim.api.nvim_set_hl(0, "CursorLine", { underdotted = true, sp = "${self.settings.eolFill.currentLineColor}" })
                  ''}
                end
              end
            end
          end

          local cursor_timer = nil
          local main_timer = nil
          local augroup = vim.api.nvim_create_augroup('eol_fill', { clear = true })

          vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'InsertEnter', 'InsertLeave' }, {
            group = augroup,
            callback = function()
              add_eol_fill()
            end
          })

          vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'VimResized', 'WinScrolled' }, {
            group = augroup,
            callback = function()
              if main_timer then
                vim.fn.timer_stop(main_timer)
              end
              main_timer = vim.fn.timer_start(30, function()
                pcall(add_eol_fill)
                main_timer = nil
              end)
            end
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            group = augroup,
            callback = function()
              if cursor_timer then
                vim.fn.timer_stop(cursor_timer)
              end
              cursor_timer = vim.fn.timer_start(60, function()
                pcall(add_eol_fill)
                cursor_timer = nil
              end)
            end
          })

          vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
            group = augroup,
            callback = clear_eol_fill
          })

          vim.defer_fn(add_eol_fill, 80)

          function _G.toggle_eol_fill()
            _G.eol_fill_enabled = not _G.eol_fill_enabled
            if _G.eol_fill_enabled then
              add_eol_fill()
            else
              clear_eol_fill()
            end

            local status = _G.eol_fill_enabled and "enabled" or "disabled"
            local icon = _G.eol_fill_enabled and "✅" or "❌"
            vim.notify("Feature " .. status, vim.log.levels.INFO, {
              icon = icon,
              title = "EOL Fill"
            })
          end
        end
      '';
    };
}
