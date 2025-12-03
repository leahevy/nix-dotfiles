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
  name = "modicator";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    colors = {
      normal = "#37f499";
      insert = "#ff6b9d";
      visual = "#c678dd";
      command = "#ffd93d";
      replace = "#ff4444";
      select = "#66d9ef";
      terminal = "#4ec9b0";
      terminalNormal = "#4ec9b0";
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.modicator = {
          enable = true;

          settings = {
            show_warnings = false;

            highlights = {
              defaults = {
                bold = true;
                italic = false;
              };
              use_cursorline_background = false;
            };

            integration = {
              lualine = {
                enabled = lib.mkIf (self.isModuleEnabled "nvim-modules.lualine") true;
                mode_section = null;
                highlight = "bg";
              };
            };
          };
        };

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}

          _G.nx_modules["97-modicator"] = function()
            vim.o.termguicolors = true
            vim.o.cursorline = true
            vim.o.number = true

            local function setup_modicator_highlights()
              vim.api.nvim_set_hl(0, "NormalMode", { fg = "${self.settings.colors.normal}", bold = true })
              vim.api.nvim_set_hl(0, "InsertMode", { fg = "${self.settings.colors.insert}", bold = true })
              vim.api.nvim_set_hl(0, "VisualMode", { fg = "${self.settings.colors.visual}", bold = true })
              vim.api.nvim_set_hl(0, "CommandMode", { fg = "${self.settings.colors.command}", bold = true })
              vim.api.nvim_set_hl(0, "ReplaceMode", { fg = "${self.settings.colors.replace}", bold = true })
              vim.api.nvim_set_hl(0, "SelectMode", { fg = "${self.settings.colors.select}", bold = true })
              vim.api.nvim_set_hl(0, "TerminalMode", { fg = "${self.settings.colors.terminal}", bold = true })
              vim.api.nvim_set_hl(0, "TerminalNormalMode", { fg = "${self.settings.colors.terminalNormal}", bold = false })
            end

            vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
              callback = function()
                vim.defer_fn(setup_modicator_highlights, 50)
              end,
            })

            setup_modicator_highlights()

            vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
              callback = function()
                local delay = vim.v.vim_did_enter == 1 and 0 or 300
                vim.defer_fn(function()
                  local mode = vim.fn.mode()
                  if mode == 'n' then
                    vim.api.nvim_exec_autocmds('ModeChanged', {pattern = 'n:n'})
                  elseif mode == 'i' then
                    vim.api.nvim_exec_autocmds('ModeChanged', {pattern = 'i:i'})
                  end
                end, delay)
              end,
            })
          end
        '';
      };
    };
}
