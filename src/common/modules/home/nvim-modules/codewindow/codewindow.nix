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
  name = "codewindow";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    autoEnable = true;
    showCursor = false;
    useLsp = true;
    useTreesitter = true;
    useGit = false;
    minimapWidth = 15;
    widthMultiplier = 2;
    windowBorder = "single";
    screenBounds = "lines";
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
      "mail"
      "qf"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "startify"
      "notify"
      "yazi"
      "trouble"
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
    activeInTerminals = false;
    borderColor = self.theme.colors.blocks.primary.foreground.html;
    backgroundColor = null;
    viewportColor = self.theme.colors.blocks.primary.foreground.html;
    viewportBGColor = self.theme.colors.blocks.primary.background.html;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          codewindow-nvim
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>m";
            action = "<cmd>lua _G.toggle_codewindow()<CR>";
            options = {
              desc = "Toggle minimap";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>m";
            desc = "Toggle minimap";
            icon = "🗺️";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-codewindow"] = function()
            local codewindow = require('codewindow')

            codewindow.setup({
              auto_enable = false,
              minimap_width = ${toString self.settings.minimapWidth},
              width_multiplier = ${toString self.settings.widthMultiplier},
              use_lsp = ${if self.settings.useLsp then "true" else "false"},
              use_treesitter = ${if self.settings.useTreesitter then "true" else "false"},
              use_git = ${if self.settings.useGit then "true" else "false"},
              show_cursor = ${if self.settings.showCursor then "true" else "false"},
              screen_bounds = '${self.settings.screenBounds}',
              window_border = '${self.settings.windowBorder}',
              exclude_filetypes = { ${
                lib.concatMapStringsSep ", " (ft: "'${ft}'") self.settings.excludeFiletypes
              } },
              active_in_terminals = ${if self.settings.activeInTerminals then "true" else "false"},
              relative = 'win'
            })

            _G.codewindow_enabled = ${if self.settings.autoEnable then "true" else "false"}

            local function refresh_treesitter(callback)
              local function do_treesitter_refresh()
                pcall(vim.treesitter.start, vim.api.nvim_get_current_buf())
                vim.cmd("syntax sync fromstart")
                if callback then
                  vim.defer_fn(callback, 250)
                end
              end

              pcall(vim.treesitter.stop, vim.api.nvim_get_current_buf())

              vim.defer_fn(do_treesitter_refresh, 150)
            end

            local function refresh_minimap()
              if not _G.codewindow_enabled then
                refresh_treesitter()
                return
              end

              local ft = vim.bo.filetype
              local excluded = { ${
                lib.concatMapStringsSep ", " (ft: "'${ft}'") self.settings.excludeFiletypes
              } }

              for _, exclude_ft in ipairs(excluded) do
                if ft == exclude_ft then
                  refresh_treesitter()
                  return
                end
              end

              if ft ~= "" and vim.bo.buftype == "" then
                refresh_treesitter(function()
                  codewindow.open_minimap()
                end)
              else
                refresh_treesitter()
              end
            end

            function _G.toggle_codewindow()
              _G.codewindow_enabled = not _G.codewindow_enabled
              if _G.codewindow_enabled then
                refresh_minimap()
              else
                codewindow.close_minimap()
              end

              local status = _G.codewindow_enabled and "enabled" or "disabled"
              local icon = _G.codewindow_enabled and "✅" or "❌"
              vim.notify(icon .. " Feature " .. status, vim.log.levels.INFO, {
                title = "Codewindow"
              })
            end

            vim.api.nvim_create_autocmd({
              "BufEnter", "BufReadPost", "BufNewFile", "TabEnter", "Syntax", "FileType", "LspAttach", "BufWinEnter"
            }, {
              callback = refresh_minimap
            })

            vim.api.nvim_create_autocmd("User", {
              pattern = "SessionLoadPost",
              callback = function()
                vim.defer_fn(function()
                  codewindow.close_minimap()
                  refresh_minimap()
                end, 500)
              end
            })

            vim.api.nvim_create_autocmd("VimEnter", {
              callback = function()
                vim.defer_fn(refresh_minimap, 300)
              end,
              once = true
            })

            vim.api.nvim_create_autocmd("TabLeave", {
              callback = function()
                if _G.codewindow_enabled then
                  codewindow.close_minimap()
                end
              end
            })

            vim.api.nvim_set_hl(0, "CodewindowBorder", { fg = "${self.settings.borderColor}" })
            vim.api.nvim_set_hl(0, "CodewindowBoundsBackground", { bg = "${self.settings.viewportColor}", fg = "${self.settings.viewportColor}" })
            vim.api.nvim_set_hl(0, "CodewindowUnderline", { bg = "${self.settings.viewportBGColor}", fg = "${self.settings.viewportBGColor}", sp = "${self.settings.viewportColor}", underline = true })${
              lib.optionalString (self.settings.backgroundColor != null)
                "\n        vim.api.nvim_set_hl(0, \"CodewindowBackground\", { bg = \"${self.settings.backgroundColor}\" })"
            }
          end
        '';
      };
    };
}
