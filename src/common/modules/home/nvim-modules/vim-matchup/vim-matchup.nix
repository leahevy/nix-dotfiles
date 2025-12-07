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
  name = "vim-matchup";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enableTransmute = true;
    enableSurround = true;
    enableOffscreen = true;
    matchParen = {
      enabled = true;
      hiSurroundAlways = false;
      showDelay = 100;
      hideDelay = 200;
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.vim-matchup = {
          enable = true;

          treesitter = lib.mkIf (self.isModuleEnabled "nvim-modules.treesitter") {
            enable = true;
          };

          settings = {
            matchparen_enabled = if self.settings.matchParen.enabled then 1 else 0;
            matchparen_deferred = 1;
            matchparen_deferred_show_delay = self.settings.matchParen.showDelay;
            matchparen_deferred_hide_delay = self.settings.matchParen.hideDelay;
            matchparen_hi_surround_always = if self.settings.matchParen.hiSurroundAlways then 1 else 0;

            transmute_enabled = if self.settings.enableTransmute then 1 else 0;
            surround_enabled = if self.settings.enableSurround then 1 else 0;

            delim_noskips = 2;
            matchparen_timeout = 300;
            matchparen_insert_timeout = 100;
            override_vimtex = 1;

            matchparen_offscreen = lib.mkIf self.settings.enableOffscreen {
              method = "popup";
              fullwidth = 0;
              highlight = "MatchParen";
              syntax_hl = 1;
              border = 1;
            };
          };
        };

        keymaps = [
          {
            mode = [
              "n"
              "x"
              "o"
            ];
            key = "%";
            action = "<Plug>(matchup-%)";
            options = {
              desc = "Navigate to matching pair";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "x"
              "o"
            ];
            key = "g%";
            action = "<Plug>(matchup-g%)";
            options = {
              desc = "Navigate to previous matching word";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "x"
              "o"
            ];
            key = "[%";
            action = "<Plug>(matchup-[%)";
            options = {
              desc = "Navigate to previous outer open";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "x"
              "o"
            ];
            key = "]%";
            action = "<Plug>(matchup-]%)";
            options = {
              desc = "Navigate to next outer close";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "x"
              "o"
            ];
            key = "z%";
            action = "<Plug>(matchup-z%)";
            options = {
              desc = "Navigate inside nearest block";
              silent = true;
            };
          }
        ]
        ++ lib.optionals self.settings.enableTransmute [
          {
            mode = "n";
            key = "ds%";
            action = "<Plug>(matchup-ds%)";
            options = {
              desc = "Delete surrounding matches";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "cs%";
            action = "<Plug>(matchup-cs%)";
            options = {
              desc = "Change surrounding matches";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") (
          [
            {
              __unkeyed-1 = "%";
              desc = "Navigate to matching pair";
              icon = "󰅪";
            }
            {
              __unkeyed-1 = "g%";
              desc = "Previous matching word";
              icon = "󰅪";
            }
            {
              __unkeyed-1 = "[%";
              desc = "Previous outer open";
              icon = "󰅪";
            }
            {
              __unkeyed-1 = "]%";
              desc = "Next outer close";
              icon = "󰅪";
            }
            {
              __unkeyed-1 = "z%";
              desc = "Inside nearest block";
              icon = "󰅪";
            }
          ]
          ++ lib.optionals self.settings.enableTransmute [
            {
              __unkeyed-1 = "ds%";
              desc = "Delete surrounding matches";
              icon = "󰅪";
            }
            {
              __unkeyed-1 = "cs%";
              desc = "Change surrounding matches";
              icon = "󰅪";
            }
          ]
        );

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["45-vim-matchup"] = function()
            vim.keymap.set({"x", "o"}, "i%", "<Plug>(matchup-i%)", {
              desc = "Inside matching pair",
              silent = true
            })
            vim.keymap.set({"x", "o"}, "a%", "<Plug>(matchup-a%)", {
              desc = "Around matching pair",
              silent = true
            })

            local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
            local bg_color = normal_bg and string.format("#%06x", normal_bg) or "${self.theme.colors.terminal.normalBackgrounds.primary.html}"

            vim.api.nvim_set_hl(0, "MatchParen", {
              bg = bg_color,
              fg = "${self.theme.colors.terminal.colors.pink.html}",
              bold = true
            })
            vim.api.nvim_set_hl(0, "MatchWord", {
              bg = bg_color,
              underline = true
            })
            vim.api.nvim_set_hl(0, "MatchParenCur", {
              underline = true,
              bold = true
            })
            vim.api.nvim_set_hl(0, "MatchWordCur", {
              underline = true,
              bold = true
            })
          end
        '';
      };
    };
}
