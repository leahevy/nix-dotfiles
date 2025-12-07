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
  name = "zen-mode";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    windowWidth = 120;
    windowHeight = 1;
    backdrop = 1;
    enableTwilight = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.zen-mode = {
          enable = true;
          settings = {
            window = {
              backdrop = self.settings.backdrop;
              width = self.settings.windowWidth;
              height = self.settings.windowHeight;
              options = {
                signcolumn = "no";
                number = false;
                relativenumber = false;
                cursorline = false;
                cursorcolumn = false;
                foldcolumn = "0";
                list = false;
              };
            };
            plugins = {
              options = {
                enabled = true;
                ruler = false;
                showcmd = false;
                laststatus = 0;
              };
              twilight = lib.mkIf (self.isModuleEnabled "nvim-modules.twilight") {
                enabled = self.settings.enableTwilight;
              };
              gitsigns = {
                enabled = false;
              };
              tmux = {
                enabled = false;
              };
            };
            on_open = lib.mkIf (self.isModuleEnabled "nvim-modules.highlight-dead-chars") {
              __raw = ''
                function()
                  _G.zen_mode_prev_eol_state = _G.eol_fill_enabled
                  if _G.eol_fill_enabled then
                    _G.eol_fill_enabled = false
                    vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('eol_fill'), 0, -1)
                  end
                end
              '';
            };
            on_close = lib.mkIf (self.isModuleEnabled "nvim-modules.highlight-dead-chars") {
              __raw = ''
                function()
                  if _G.zen_mode_prev_eol_state ~= nil then
                    _G.eol_fill_enabled = _G.zen_mode_prev_eol_state
                    _G.zen_mode_prev_eol_state = nil
                    if _G.eol_fill_enabled then
                      vim.defer_fn(function()
                        if _G.eol_fill_enabled then
                          local ns = vim.api.nvim_create_namespace('eol_fill')
                          local bufnr = vim.api.nvim_get_current_buf()
                          local winnr = vim.api.nvim_get_current_win()
                          local win_width = vim.api.nvim_win_get_width(winnr)
                          vim.cmd('doautocmd BufEnter')
                        end
                      end, 50)
                    end
                  end
                end
              '';
            };
          };
        };

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>Xz";
            desc = "Toggle zen mode";
            icon = "🧘";
          }
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>Xz";
            action = "<cmd>lua _G.toggle_zen_mode()<cr>";
            options = {
              desc = "Toggle zen mode";
              silent = true;
            };
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-zen-mode"] = function()
            _G.zen_mode_enabled = false

            function _G.toggle_zen_mode()
              _G.zen_mode_enabled = not _G.zen_mode_enabled
              require("zen-mode").toggle()

              local status = _G.zen_mode_enabled and "enabled" or "disabled"
              local icon = _G.zen_mode_enabled and "✅" or "❌"
              vim.notify(icon .. " Feature " .. status, vim.log.levels.INFO, {
                title = "Zen Mode"
              })
            end

            vim.api.nvim_set_hl(0, "ZenBg", { bg = "${self.theme.colors.terminal.normalBackgrounds.primary.html}" })
          end
        '';
      };
    };
}
