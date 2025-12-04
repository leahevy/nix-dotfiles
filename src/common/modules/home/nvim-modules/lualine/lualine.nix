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
  name = "lualine";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    theme = "auto";
    powerlineSymbols = true;
    themeOverride = true;
    transparentBackground = true;
    alwaysShowTabline = false;
    iconsEnabled = true;
    alwaysDivideMiddle = true;
    showDateTime = false;
    enableWinbar = true;
    disabledGeneralFiletypes = [
      "dashboard"
      "alpha"
      "startify"
      "mason"
      "notify"
      "nofile"
      "nowrite"
      "Codewindow"
    ];

    disabledWinbarFiletypes = [
      "dap-repl"
      "neotest-output-panel"
      "neotest-summary"
      "OverseerList"
      "dapui_scopes"
      "dapui_breakpoints"
      "dapui_stacks"
      "dapui_watches"
      "dapui-repl"
      "dapui_console"
      "prompt"
      "lazy"
      "checkhealth"
      "trouble"
      "Trouble"
      "telescope"
      "TelescopePrompt"
      "TelescopeResults"
      "NvimTree"
      "neo-tree"
      "netrw"
      "help"
      "man"
      "qf"
      "quickfix"
      "toggleterm"
      "terminal"
      "yazi"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "lspinfo"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.lualine = {
        enable = true;
        settings = {
          options = {
            theme = if self.settings.themeOverride then "nx" else self.settings.theme;
            globalstatus = true;
            section_separators = lib.mkIf self.settings.powerlineSymbols {
              left = "";
              right = "";
            };
            component_separators = lib.mkIf self.settings.powerlineSymbols {
              left = "";
              right = "";
            };
            always_show_tabline = self.settings.alwaysShowTabline;
            icons_enabled = self.settings.iconsEnabled;
            always_divide_middle = self.settings.alwaysDivideMiddle;
            disabled_filetypes = {
              statusline = self.settings.disabledGeneralFiletypes;
              winbar = self.settings.disabledGeneralFiletypes ++ self.settings.disabledWinbarFiletypes;
            };
            refresh = {
              statusline = 500;
              tabline = 1000;
              winbar = 1000;
            };
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [
              "branch"
              "diff"
              "diagnostics"
            ];
            lualine_c = [ "filename" ];
            lualine_x = [
              "searchcount"
              "encoding"
              "fileformat"
              "filetype"
            ];
            lualine_y = [
              "selectioncount"
              "progress"
            ];
            lualine_z = lib.mkMerge [
              [ "location" ]
              (lib.mkIf self.settings.showDateTime [ "datetime" ])
            ];
          };
          tabline = {
            lualine_a = [ "buffers" ];
            lualine_b = [ ];
            lualine_c = [ ];
            lualine_x = [ ];
            lualine_y = [ ];
            lualine_z = [ "tabs" ];
          };
          inactive_sections = {
            lualine_a = [ ];
            lualine_b = [ ];
            lualine_c = [ "filename" ];
            lualine_x = [ "location" ];
            lualine_y = [ ];
            lualine_z = [ ];
          };
        }
        // lib.optionalAttrs self.settings.enableWinbar {
          winbar = {
            lualine_a = [ ];
            lualine_b = [ ];
            lualine_c = [
              {
                __unkeyed-1 = "filename";
                path = 1;
                symbols = {
                  modified = " ●";
                  readonly = " [readonly]";
                  unnamed = " [unnamed]";
                  newfile = " [new]";
                };
              }
            ];
            lualine_x = [ "filetype" ];
            lualine_y = [ ];
            lualine_z = [ ];
          };
          inactive_winbar = {
            lualine_a = [ ];
            lualine_b = [ ];
            lualine_c = [
              {
                __unkeyed-1 = "filename";
                path = 1;
              }
            ];
            lualine_x = [ ];
            lualine_y = [ ];
            lualine_z = [ ];
          };
        }
        // {
          extensions = lib.mkMerge [
            [ "quickfix" ]
            (lib.mkIf (self.isModuleEnabled "nvim-modules.dap") [ "nvim-dap-ui" ])
            (lib.mkIf (self.isModuleEnabled "nvim-modules.fugitive") [ "fugitive" ])
            (lib.mkIf (self.isModuleEnabled "nvim-modules.nvim-tree") [ "nvim-tree" ])
            (lib.mkIf (self.isModuleEnabled "nvim-modules.toggleterm") [ "toggleterm" ])
            (lib.mkIf (self.isModuleEnabled "nvim-modules.overseer") [ "overseer" ])
            (lib.mkIf (self.isModuleEnabled "nvim-modules.trouble") [ "trouble" ])
          ];
        };
      };

      home.file.".config/nvim/lua/lualine/themes/nx.lua".text = lib.mkIf self.settings.themeOverride ''
        local transparent = ${if self.settings.transparentBackground then "true" else "false"}

        local colors = {
          normal_fg = '#37f499',
          normal_bg = transparent and nil or '#1a4d33',
          insert_fg = '#00ff00',
          insert_bg = transparent and nil or '#004400',
          visual_fg = '#ff00ff',
          visual_bg = transparent and nil or '#440044',
          replace_fg = '#ff4444',
          replace_bg = transparent and nil or '#440000',
          command_fg = '#ffaa00',
          command_bg = transparent and nil or '#332200',
          section_fg = '#cccccc',
          section_bg = transparent and nil or '#0a0a0a',
          tertiary_fg = '#888888',
          tertiary_bg = transparent and nil or '#000000',
          inactive_fg = '#666666',
          inactive_bg = transparent and nil or '#000000',
        }

        local theme = {
          normal = {
            a = { fg = colors.normal_fg, bg = colors.normal_bg, gui = 'bold' },
            b = { fg = colors.section_fg, bg = colors.section_bg },
            c = { fg = colors.tertiary_fg, bg = colors.tertiary_bg },
          },
          insert = {
            a = { fg = colors.insert_fg, bg = colors.insert_bg, gui = 'bold' },
            b = { fg = colors.section_fg, bg = colors.section_bg },
            c = { fg = colors.tertiary_fg, bg = colors.tertiary_bg },
          },
          visual = {
            a = { fg = colors.visual_fg, bg = colors.visual_bg, gui = 'bold' },
            b = { fg = colors.section_fg, bg = colors.section_bg },
            c = { fg = colors.tertiary_fg, bg = colors.tertiary_bg },
          },
          replace = {
            a = { fg = colors.replace_fg, bg = colors.replace_bg, gui = 'bold' },
            b = { fg = colors.section_fg, bg = colors.section_bg },
            c = { fg = colors.tertiary_fg, bg = colors.tertiary_bg },
          },
          command = {
            a = { fg = colors.command_fg, bg = colors.command_bg, gui = 'bold' },
            b = { fg = colors.section_fg, bg = colors.section_bg },
            c = { fg = colors.tertiary_fg, bg = colors.tertiary_bg },
          },
          inactive = {
            a = { fg = colors.inactive_fg, bg = colors.inactive_bg, gui = 'bold' },
            b = { fg = colors.inactive_fg, bg = colors.inactive_bg },
            c = { fg = colors.inactive_fg, bg = colors.inactive_bg },
          },
        }
        theme.terminal = theme.insert

        return theme
      '';
    };
}
