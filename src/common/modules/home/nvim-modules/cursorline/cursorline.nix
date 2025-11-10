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
  name = "cursorline";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enableCursorline = false;
    enableCursorword = true;
    cursorlineTimeout = 1000;
    cursorlineNumber = true;
    cursorwordMinLength = 1;
    cursorwordUnderline = true;
    excludeFiletypes = [
      ""
      "dashboard"
      "alpha"
      "help"
      "NvimTree"
      "neo-tree"
      "telescope"
      "TelescopePrompt"
      "TelescopeResults"
      "Trouble"
      "trouble"
      "lazy"
      "mason"
      "notify"
      "toggleterm"
      "terminal"
      "qf"
      "quickfix"
      "man"
      "lspinfo"
      "checkhealth"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "Codewindow"
      "yazi"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      # Modified version of nvim-cursorline with filetype exclusions
      #  Original: https://github.com/ya2s/nvim-cursorline
      #  License: MIT
      home.file.".config/nvim/lua/nvim-cursorline.lua".text = ''
        local M = {}

        local w = vim.w
        local a = vim.api
        local wo = vim.wo
        local fn = vim.fn
        local hl = a.nvim_set_hl
        local au = a.nvim_create_autocmd
        local timer = vim.loop.new_timer()

        local excluded_ft_set = {}

        local DEFAULT_OPTIONS = {
          cursorline = {
            enable = true,
            timeout = 1000,
            number = false,
          },
          cursorword = {
            enable = true,
            min_length = 3,
            hl = { underline = true },
          },
        }

        local function is_excluded()
          return excluded_ft_set[vim.bo.filetype] or vim.bo.buftype ~= ""
        end

        local function matchadd()
          if is_excluded() then
            return
          end

          local column = a.nvim_win_get_cursor(0)[2]
          local line = a.nvim_get_current_line()
          local cursorword = fn.matchstr(line:sub(1, column + 1), [[\k*$]])
            .. fn.matchstr(line:sub(column + 1), [[^\k*]]):sub(2)

          if cursorword == w.cursorword then
            return
          end
          w.cursorword = cursorword
          if w.cursorword_id then
            vim.call("matchdelete", w.cursorword_id)
            w.cursorword_id = nil
          end
          if
            cursorword == ""
            or #cursorword > 100
            or #cursorword < M.options.cursorword.min_length
            or string.find(cursorword, "[\192-\255]+") ~= nil
          then
            return
          end
          local pattern = [[\<]] .. cursorword .. [[\>]]
          w.cursorword_id = fn.matchadd("CursorWord", pattern, -1)
        end

        function M.setup(options)
          M.options = vim.tbl_deep_extend("force", DEFAULT_OPTIONS, options or {})

          if M.options.cursorline.enable then
            wo.cursorline = true
            au("WinEnter", {
              callback = function()
                if not is_excluded() then
                  wo.cursorline = true
                end
              end,
            })
            au("WinLeave", {
              callback = function()
                wo.cursorline = false
              end,
            })
            au({ "CursorMoved", "CursorMovedI" }, {
              callback = function()
                if is_excluded() then
                  return
                end

                if M.options.cursorline.number then
                  wo.cursorline = false
                else
                  wo.cursorlineopt = "number"
                end
                timer:start(
                  M.options.cursorline.timeout,
                  0,
                  vim.schedule_wrap(function()
                    if M.options.cursorline.number then
                      wo.cursorline = true
                    else
                      wo.cursorlineopt = "both"
                    end
                  end)
                )
              end,
            })
          end

          if M.options.cursorword.enable then
            au("VimEnter", {
              callback = function()
                hl(0, "CursorWord", M.options.cursorword.hl)
                matchadd()
              end,
            })
            au({ "CursorMoved", "CursorMovedI" }, {
              callback = function()
                matchadd()
              end,
            })
          end
        end

        function M.set_excluded_filetypes(filetypes)
          excluded_ft_set = {}
          for _, ft in ipairs(filetypes) do
            excluded_ft_set[ft] = true
          end
        end

        M.options = nil

        return M
      '';

      home.file.".config/nvim-init/45-cursorline-setup.lua".text = ''
        local cursorline = require('nvim-cursorline')

        cursorline.set_excluded_filetypes({
          ${lib.concatMapStringsSep ", " (ft: "\"${ft}\"") self.settings.excludeFiletypes}
        })

        cursorline.setup({
          cursorline = {
            enable = ${if self.settings.enableCursorline then "true" else "false"},
            timeout = ${toString self.settings.cursorlineTimeout},
            number = ${if self.settings.cursorlineNumber then "true" else "false"},
          },
          cursorword = {
            enable = ${if self.settings.enableCursorword then "true" else "false"},
            min_length = ${toString self.settings.cursorwordMinLength},
            hl = { underline = ${if self.settings.cursorwordUnderline then "true" else "false"} },
          },
        })
      '';
    };
}
