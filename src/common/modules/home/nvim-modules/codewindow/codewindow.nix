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
    useGit = true;
    minimapWidth = 6;
    widthMultiplier = 6;
    windowBorder = "single";
    screenBounds = "lines";
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
      "gitrebase"
      "fugitive"
      "startify"
      ""
    ];
    activeInTerminals = false;
    borderColor = "#19cd04";
    backgroundColor = null;
    viewportColor = "#19cd04";
    viewportBGColor = "#113302";
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
      };

      home.file.".config/nvim-init/50-codewindow.lua".text = ''
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

        local function handle_minimap()
          if _G.codewindow_enabled then
            local ft = vim.bo.filetype
            local excluded = { ${
              lib.concatMapStringsSep ", " (ft: "'${ft}'") self.settings.excludeFiletypes
            } }

            for _, exclude_ft in ipairs(excluded) do
              if ft == exclude_ft then
                return
              end
            end

            codewindow.open_minimap()
          end
        end

        function _G.toggle_codewindow()
          _G.codewindow_enabled = not _G.codewindow_enabled
          if _G.codewindow_enabled then
            handle_minimap()
          else
            codewindow.close_minimap()
          end
        end

        vim.api.nvim_create_autocmd({
          "BufEnter", "TabEnter"
        }, {
          callback = function()
            vim.defer_fn(handle_minimap, 10)
          end
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
      '';
    };
}
