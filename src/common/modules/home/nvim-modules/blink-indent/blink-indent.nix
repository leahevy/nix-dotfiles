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
  namespace = "home";

  settings = {
    enableOnStart = true;

    excludeFiletypes = [
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
      static = "#2c2c2c";
      color1 = "#e06c75";
      color2 = "#d19a66";
      color3 = "#e5c07b";
      color4 = "#98c379";
      color5 = "#c678dd";
      color6 = "#56b6c2";
      color7 = "#61afef";
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = [
          (pkgs.vimUtils.buildVimPlugin {
            name = "blink-indent";
            src = pkgs.fetchFromGitHub {
              owner = "saghen";
              repo = "blink.indent";
              rev = "a8feeeae8510d16f26afbb5c81f2ad1ccea38d62";
              hash = "sha256-zs39HyluWYoGMPnjtEb+2JAyZsUoWO4sTMfx6TyCqOI=";
            };
          })
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>i";
            action = "<cmd>lua _G.toggle_blink_indent()<CR>";
            options = {
              desc = "Toggle indent guides";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>i";
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
                highlights = { 'BlinkIndent' },
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

            vim.api.nvim_set_hl(0, "BlinkIndent", { fg = "${self.settings.colors.static}" })
            vim.api.nvim_set_hl(0, "BlinkIndentScope", { fg = "${self.settings.colors.color7}" })

            vim.api.nvim_set_hl(0, "BlinkIndentRed", { fg = "${self.settings.colors.color1}" })
            vim.api.nvim_set_hl(0, "BlinkIndentOrange", { fg = "${self.settings.colors.color2}" })
            vim.api.nvim_set_hl(0, "BlinkIndentYellow", { fg = "${self.settings.colors.color3}" })
            vim.api.nvim_set_hl(0, "BlinkIndentGreen", { fg = "${self.settings.colors.color4}" })
            vim.api.nvim_set_hl(0, "BlinkIndentViolet", { fg = "${self.settings.colors.color5}" })
            vim.api.nvim_set_hl(0, "BlinkIndentCyan", { fg = "${self.settings.colors.color6}" })
            vim.api.nvim_set_hl(0, "BlinkIndentBlue", { fg = "${self.settings.colors.color7}" })

            vim.api.nvim_set_hl(0, "BlinkIndentRedUnderline", { fg = "${self.settings.colors.color1}", underline = true })
            vim.api.nvim_set_hl(0, "BlinkIndentOrangeUnderline", { fg = "${self.settings.colors.color2}", underline = true })
            vim.api.nvim_set_hl(0, "BlinkIndentYellowUnderline", { fg = "${self.settings.colors.color3}", underline = true })
            vim.api.nvim_set_hl(0, "BlinkIndentGreenUnderline", { fg = "${self.settings.colors.color4}", underline = true })
            vim.api.nvim_set_hl(0, "BlinkIndentVioletUnderline", { fg = "${self.settings.colors.color5}", underline = true })
            vim.api.nvim_set_hl(0, "BlinkIndentCyanUnderline", { fg = "${self.settings.colors.color6}", underline = true })
            vim.api.nvim_set_hl(0, "BlinkIndentBlueUnderline", { fg = "${self.settings.colors.color7}", underline = true })

            vim.g.indent_guide = ${if self.settings.enableOnStart then "true" else "false"}

            function _G.toggle_blink_indent()
              vim.g.indent_guide = not vim.g.indent_guide
              require('blink.indent').enable(vim.g.indent_guide)

              local status = vim.g.indent_guide and "enabled" or "disabled"
              local icon = vim.g.indent_guide and "✅" or "❌"
              vim.notify(icon .. " Feature " .. status, vim.log.levels.INFO, {
                title = "Blink Indent"
              })
            end
          end
        '';
      };
    };
}
