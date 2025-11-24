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
    whiteSpaceColor = "#404040";
    eolFill = {
      enabledOnStart = true;
      char = "‧";
      currentLineChar = "┄";
      color = "#1c1c1c";
      currentLineColor = "#61afef";
      delimiterChars = " ";
      onlyFillIfAllFit = true;
      onlyShowOnCurrentLine = false;
    };
    excludeFiletypes = [
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
            key = "<leader>o";
            action = "<cmd>lua _G.toggle_eol_fill()<CR>";
            options = {
              desc = "Toggle EOL fill";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>o";
            desc = "Toggle EOL fill";
            icon = "🔲";
          }
        ];
      };

      home.file.".config/nvim-init/50-highlight-dead-chars.lua".text = ''
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
            if line_content and line_content ~= "" then
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

              if dots_needed > 0 then
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
                        local current_indent = math.floor(vim.fn.indent(line_nr + 1) / vim.bo.shiftwidth)
                        local effective_indent = current_indent

                        local next_line_nr = line_nr + 2
                        local total_lines = vim.api.nvim_buf_line_count(bufnr)
                        while next_line_nr <= total_lines do
                          local next_line = vim.api.nvim_buf_get_lines(bufnr, next_line_nr - 1, next_line_nr, false)[1]
                          if next_line and vim.trim(next_line) ~= "" then
                            local next_indent = math.floor(vim.fn.indent(next_line_nr) / vim.bo.shiftwidth)
                            if next_indent > current_indent then
                              effective_indent = next_indent
                            end
                            break
                          end
                          next_line_nr = next_line_nr + 1
                        end

                        if effective_indent > 0 then
                          local blink_indent_groups = {
                            "BlinkIndentRed", "BlinkIndentOrange", "BlinkIndentYellow",
                            "BlinkIndentGreen", "BlinkIndentViolet", "BlinkIndentCyan", "BlinkIndentBlue"
                          }
                          local group_index = ((effective_indent - 1) % #blink_indent_groups) + 1
                          highlight_group = blink_indent_groups[group_index]
                        else
                          highlight_group = "EolFillCurrent"
                        end
                      ''}
                      ${lib.optionalString (!self.isModuleEnabled "nvim-modules.blink-indent") ''
                        highlight_group = "EolFillCurrent"
                      ''}
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

                    ::continue::
                  end
                end
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
          vim.notify(icon .. " Feature " .. status, vim.log.levels.INFO, {
            title = "EOL Fill"
          })
        end
      '';
    };
}
