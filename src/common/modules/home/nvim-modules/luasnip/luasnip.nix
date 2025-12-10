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
  name = "luasnip";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = lib.optionals (self.isModuleEnabled "nvim-modules.telescope") [
          (pkgs.vimUtils.buildVimPlugin {
            name = "telescope-luasnip-nvim";
            src = pkgs.fetchFromGitHub {
              owner = "benfowler";
              repo = "telescope-luasnip.nvim";
              rev = "07a2a2936a7557404c782dba021ac0a03165b343";
              hash = "sha256-9XsV2hPjt05q+y5FiSbKYYXnznDKYOsDwsVmfskYd3M=";
            };
            dependencies = with pkgs.vimPlugins; [
              telescope-nvim
              luasnip
            ];
          })
        ];

        plugins = {
          luasnip = {
            enable = true;
            settings = {
              enable_autosnippets = true;
              store_selection_keys = "<Tab>";
            };
          };

          friendly-snippets = {
            enable = true;
          };
        };

        keymaps = [
          {
            mode = [
              "i"
              "s"
            ];
            key = "<C-u>";
            action = "<cmd>lua require('luasnip').expand_or_jump()<CR>";
            options = {
              silent = true;
              desc = "Expand snippet or jump forward";
            };
          }
          {
            mode = [
              "i"
              "s"
            ];
            key = "<C-k>";
            action = "<cmd>lua if require('luasnip').jumpable(-1) then require('luasnip').jump(-1) end<CR>";
            options = {
              silent = true;
              desc = "Jump backward in snippet";
            };
          }
          {
            mode = [
              "i"
              "s"
            ];
            key = "<C-j>";
            action = "<cmd>lua if require('luasnip').jumpable(1) then require('luasnip').jump(1) end<CR>";
            options = {
              silent = true;
              desc = "Jump forward in snippet";
            };
          }
          {
            mode = [
              "i"
              "s"
            ];
            key = "<C-y>";
            action = "<cmd>lua if require('luasnip').choice_active() then require('luasnip').change_choice(1) end<CR>";
            options = {
              silent = true;
              desc = "Cycle through choices";
            };
          }
        ]
        ++ lib.optionals (self.isModuleEnabled "nvim-modules.telescope") [
          {
            mode = "n";
            key = "<leader>js";
            action = "<cmd>lua require('telescope').extensions.luasnip.luasnip{}<CR>";
            options = {
              silent = true;
              desc = "Browse snippets";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") (
          [
            {
              __unkeyed-1 = "<C-u>";
              mode = [
                "i"
                "s"
              ];
              desc = "Expand snippet or jump forward";
              icon = "🔧";
            }
            {
              __unkeyed-1 = "<C-k>";
              mode = [
                "i"
                "s"
              ];
              desc = "Jump backward in snippet";
              icon = "⬅";
            }
            {
              __unkeyed-1 = "<C-j>";
              mode = [
                "i"
                "s"
              ];
              desc = "Jump forward in snippet";
              icon = "⬇";
            }
            {
              __unkeyed-1 = "<C-y>";
              mode = [
                "i"
                "s"
              ];
              desc = "Cycle through choices";
              icon = "🔄";
            }
          ]
          ++ lib.optionals (self.isModuleEnabled "nvim-modules.telescope") [
            {
              __unkeyed-1 = "<leader>js";
              mode = "n";
              desc = "Browse snippets";
              icon = "📋";
            }
          ]
        );

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-luasnip"] = function()
            local luasnip = require('luasnip')

            require("luasnip.loaders.from_vscode").lazy_load()
            require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })

            luasnip.config.set_config({
              history = true,
              updateevents = "TextChanged,TextChangedI",
              enable_autosnippets = true,
              ext_opts = {
                [require("luasnip.util.types").choiceNode] = {
                  active = {
                    virt_text = { { "●", "Operator" } }
                  }
                }
              }
            })

            vim.api.nvim_set_hl(0, "LuasnipInsertNodePassive", { fg = "${self.theme.colors.separators.normal.html}" })
            vim.api.nvim_set_hl(0, "LuasnipInsertNodeActive", { fg = "${self.theme.colors.semantic.info.html}" })
            vim.api.nvim_set_hl(0, "LuasnipExitNodePassive", { fg = "${self.theme.colors.separators.normal.html}" })
            vim.api.nvim_set_hl(0, "LuasnipExitNodeActive", { fg = "${self.theme.colors.semantic.success.html}" })
            vim.api.nvim_set_hl(0, "LuasnipChoiceNodePassive", { fg = "${self.theme.colors.separators.normal.html}" })
            vim.api.nvim_set_hl(0, "LuasnipChoiceNodeActive", { fg = "${self.theme.colors.semantic.warning.html}" })

            ${lib.optionalString (self.isModuleEnabled "nvim-modules.telescope") ''
              local telescope = require('telescope')
              telescope.load_extension('luasnip')
            ''}
          end
        '';
      };
    };
}
