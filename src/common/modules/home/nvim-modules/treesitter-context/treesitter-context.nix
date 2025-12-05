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
  name = "treesitter-context";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      nvim-modules = {
        treesitter = true;
      };
    };
  };

  settings = {
    maxLines = 1;
    minWindowHeight = 0;
    lineNumbers = true;
    multilineThreshold = 20;
    trimScope = "outer";
    mode = "cursor";
    separator = "┄";
    zindex = 20;

    disabledFiletypes = [
      ""
      "undotree"
      "diff"
      "help"
      "dashboard"
      "alpha"
      "startify"
      "NvimTree"
      "neo-tree"
      "netrw"
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
      "lspinfo"
      "checkhealth"
      "man"
      "qf"
      "quickfix"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "nofile"
      "nowrite"
      "prompt"
      "dap-repl"
      "dapui_scopes"
      "dapui_breakpoints"
      "dapui_stacks"
      "dapui_watches"
      "dapui-repl"
      "dapui_console"
      "neotest-output-panel"
      "neotest-summary"
      "OverseerList"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.treesitter-context = {
          enable = true;

          settings = {
            max_lines = self.settings.maxLines;
            min_window_height = self.settings.minWindowHeight;
            line_numbers = self.settings.lineNumbers;
            multiline_threshold = self.settings.multilineThreshold;
            trim_scope = self.settings.trimScope;
            mode = self.settings.mode;
            separator = self.settings.separator;
            zindex = self.settings.zindex;

            on_attach.__raw = ''
              function(buf)
                local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
                local disabled_filetypes = {
                  ${lib.concatMapStringsSep ", " (ft: "\"${ft}\"") self.settings.disabledFiletypes}
                }

                for _, ft in ipairs(disabled_filetypes) do
                  if filetype == ft then
                    return false
                  end
                end

                return true
              end
            '';
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>Xc";
            action = "<cmd>TSContextToggle<CR>";
            options = {
              desc = "Toggle treesitter context";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>Xc";
            desc = "Toggle treesitter context";
            icon = "󱎸";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["45-treesitter-context"] = function()
            local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
            local bg_color = normal_bg and string.format("#%06x", normal_bg) or "#000000"

            vim.api.nvim_set_hl(0, "TreesitterContext", {
              bg = bg_color
            })
            vim.api.nvim_set_hl(0, "TreesitterContextSeparator", {
              bg = bg_color,
              fg = "#37f499"
            })
          end
        '';
      };
    };
}
