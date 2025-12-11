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
    alwaysShowTabline = true;
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
      "diff"
      "undotree"
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
      programs.nixvim.opts.showmode = false;

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
              statusline = 150;
              tabline = 150;
              winbar = 150;
            };
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [
              "branch"
              "diff"
              "diagnostics"
            ];
            lualine_c = [ { __raw = "require('components.custom_filename').statusline"; } ];
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
            lualine_a = [ { __raw = "require('components.custom_buffers')"; } ];
            lualine_b = [ ];
            lualine_c = [ ];
            lualine_x = [ ];
            lualine_y = [ ];
            lualine_z = [ "tabs" ];
          };
          inactive_sections = {
            lualine_a = [ ];
            lualine_b = [ ];
            lualine_c = [ { __raw = "require('components.custom_filename').statusline"; } ];
            lualine_x = [ "location" ];
            lualine_y = [ ];
            lualine_z = [ ];
          };
        }
        // lib.optionalAttrs self.settings.enableWinbar {
          winbar = {
            lualine_a = [ ];
            lualine_b = [ ];
            lualine_c = [ { __raw = "require('components.custom_filename').winbar"; } ];
            lualine_x = [ "filetype" ];
            lualine_y = [ ];
            lualine_z = [ ];
          };
          inactive_winbar = {
            lualine_a = [ ];
            lualine_b = [ ];
            lualine_c = [ { __raw = "require('components.custom_filename').winbar_inactive"; } ];
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

      home.file.".config/nvim/lua/components/custom_buffers.lua".text = ''
        local original_buffers = require('lualine.components.buffers')

        local custom_buffers = original_buffers:extend()


        local original_init = custom_buffers.init
        function custom_buffers:init(options)
          options = options or {}
          options.symbols = {
            modified = " [+]",
            alternate_file = "#",
            directory = "",
          }
          options.use_mode_colors = false

          original_init(self, options)
        end

        local modified_highlights = nil

        function custom_buffers:new_buffer(bufnr, buf_index)
          if not bufnr or type(bufnr) ~= 'number' or bufnr <= 0 then
            bufnr = vim.api.nvim_get_current_buf()
          end

          if not modified_highlights and self.create_hl then
            self.options.use_mode_colors = false

            local original_active_color = self.options.buffers_color and self.options.buffers_color.active or self:get_hl()
            local original_inactive_color = self.options.buffers_color and self.options.buffers_color.inactive or self:get_hl() .. '_inactive'

            modified_highlights = {
              modified_active = self:create_hl({fg = '${self.theme.colors.blocks.critical.foreground.html}', bg = '${self.theme.colors.blocks.critical.background.html}', gui = 'bold'}, 'buffer_modified_active'),
              modified_inactive = self:create_hl({fg = '${self.theme.colors.blocks.critical.foreground.html}', bg = 'NONE'}, 'buffer_modified_inactive'),
              normal_active = self:create_hl(original_active_color, 'buffer_normal_active'),
              normal_inactive = self:create_hl(original_inactive_color, 'buffer_normal_inactive'),
            }
          end

          local Buffer = require('lualine.components.buffers.buffer')

          local is_modified = false
          if bufnr and type(bufnr) == 'number' and vim.api.nvim_buf_is_valid(bufnr) then
            is_modified = vim.fn.getbufvar(bufnr, '&modified') == 1
          end

          local highlights = {
            active = is_modified and modified_highlights.modified_active or modified_highlights.normal_active,
            inactive = is_modified and modified_highlights.modified_inactive or modified_highlights.normal_inactive,
          }

          local buffer = Buffer:new {
            bufnr = bufnr,
            buf_index = buf_index or "",
            options = self.options,
            highlights = highlights,
          }

          return buffer
        end

        return custom_buffers
      '';

      home.file.".config/nvim/lua/components/custom_filename.lua".text = ''
        local custom_fname = require('lualine.components.filename'):extend()
        local highlight = require('lualine.highlight')
        local default_status_colors = {
          saved = '${self.theme.colors.blocks.primary.foreground.html}',
          modified = '${self.theme.colors.blocks.critical.foreground.html}'
        }

        function custom_fname:init(options)
          custom_fname.super.init(self, options)
          self.status_colors = {
            saved = highlight.create_component_highlight_group(
              {fg = default_status_colors.saved, gui = 'bold'}, 'filename_status_saved', self.options),
            modified = highlight.create_component_highlight_group(
              {fg = default_status_colors.modified, gui = 'bold'}, 'filename_status_modified', self.options),
          }
          if self.options.color == nil then self.options.color = "" end
        end

        function custom_fname:update_status()
          local data = custom_fname.super.update_status(self)
          data = highlight.component_format_highlight(vim.bo.modified
                                                      and self.status_colors.modified
                                                      or self.status_colors.saved) .. data
          return data
        end

        local winbar_component = custom_fname:extend()
        function winbar_component:init(options)
          options = options or {}
          options.path = 1
          options.symbols = {
            modified = "",
            readonly = " [readonly]",
            unnamed = " [unnamed]",
            newfile = " [new]",
          }
          custom_fname.init(self, options)
          self.status_colors = {
            saved = highlight.create_component_highlight_group(
              {fg = '${self.theme.colors.separators.normal.html}'}, 'filename_winbar_saved', self.options),
            modified = highlight.create_component_highlight_group(
              {fg = '${self.theme.colors.semantic.error.html}'}, 'filename_winbar_modified', self.options),
          }
        end

        local winbar_inactive_component = custom_fname:extend()
        function winbar_inactive_component:init(options)
          options = options or {}
          options.path = 2
          custom_fname.init(self, options)
          self.status_colors = {
            saved = highlight.create_component_highlight_group(
              {fg = '${self.theme.colors.separators.dark.html}'}, 'filename_winbar_inactive_saved', self.options),
            modified = highlight.create_component_highlight_group(
              {fg = '${self.theme.colors.semantic.error.html}'}, 'filename_winbar_inactive_modified', self.options),
          }
        end

        return {
          statusline = custom_fname,
          winbar = winbar_component,
          winbar_inactive = winbar_inactive_component
        }
      '';

      home.file.".config/nvim/lua/lualine/themes/nx.lua".text = lib.mkIf self.settings.themeOverride ''
        local transparent = ${if self.settings.transparentBackground then "true" else "false"}

        local colors = {
          normal_fg = '${self.theme.colors.blocks.primary.foreground.html}',
          normal_bg = transparent and nil or '${self.theme.colors.blocks.primary.background.html}',
          insert_fg = '${self.theme.colors.blocks.accent.foreground.html}',
          insert_bg = transparent and nil or '${self.theme.colors.blocks.accent.background.html}',
          visual_fg = '${self.theme.colors.blocks.highlight.foreground.html}',
          visual_bg = transparent and nil or '${self.theme.colors.blocks.highlight.background.html}',
          replace_fg = '${self.theme.colors.blocks.critical.foreground.html}',
          replace_bg = transparent and nil or '${self.theme.colors.blocks.critical.background.html}',
          command_fg = '${self.theme.colors.blocks.warning.foreground.html}',
          command_bg = transparent and nil or '${self.theme.colors.blocks.warning.background.html}',
          section_fg = '${self.theme.colors.terminal.foregrounds.primary.html}',
          section_bg = transparent and nil or '${self.theme.colors.terminal.normalBackgrounds.secondary.html}',
          tertiary_fg = '${self.theme.colors.terminal.foregrounds.dim.html}',
          tertiary_bg = transparent and nil or '${self.theme.colors.terminal.normalBackgrounds.primary.html}',
          inactive_fg = '${self.theme.colors.separators.normal.html}',
          inactive_bg = transparent and nil or '${self.theme.colors.terminal.normalBackgrounds.primary.html}',
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
