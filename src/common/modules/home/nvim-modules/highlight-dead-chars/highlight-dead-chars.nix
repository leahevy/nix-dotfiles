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
      color = "#1c1c1c";
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

          local start_line = math.max(0, vim.fn.line('w0') - 2)
          local end_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, vim.fn.line('w$') + 1)

          local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)

          for i, line_content in ipairs(lines) do
            if line_content and line_content ~= "" then
              local line_nr = start_line + i - 1
              local content_width = vim.fn.strdisplaywidth(line_content)
              local dots_needed = math.max(0, win_width - content_width - 3)

              if dots_needed > 0 then
                vim.api.nvim_buf_set_extmark(bufnr, ns, line_nr, -1, {
                  virt_text = {{ string.rep("${self.settings.eolFill.char}", dots_needed), "EolFill" }},
                  virt_text_pos = "eol",
                  priority = 100
                })
              end
            end
          end
        end

        local cursor_timer = nil
        local main_timer = nil
        local augroup = vim.api.nvim_create_augroup('eol_fill', { clear = true })

        vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter' }, {
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
        end
      '';
    };
}
