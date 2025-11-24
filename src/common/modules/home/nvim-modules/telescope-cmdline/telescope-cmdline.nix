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
  name = "telescope-cmdline";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enable = true;

    picker = {
      layout_config = {
        width = 120;
        height = 25;
      };
    };

    mappings = {
      complete = "<Tab>";
      run_selection = "<M-CR>";
      run_input = "<CR>";
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = [
          (pkgs.vimUtils.buildVimPlugin {
            name = "telescope-cmdline";
            src = pkgs.fetchFromGitHub {
              owner = "jonarrien";
              repo = "telescope-cmdline.nvim";
              rev = "7106ff7357d9d3cde3e71cd8fe8998d2f96a1bdd";
              hash = "sha256-xpgWxjng4X1LapjuJkhVM7gQbpiZ9pS6fTy+L2Y8IM8=";
            };
            dependencies = with pkgs.vimPlugins; [
              telescope-nvim
              plenary-nvim
            ];
          })
        ];

        keymaps = [
          {
            mode = "n";
            key = ";";
            action = "<cmd>Telescope cmdline<CR>";
            options = {
              desc = "Open telescope cmdline";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<M-;>";
            action = ":";
            options = {
              desc = "Command mode";
              silent = false;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = ";";
            desc = "Open telescope cmdline";
            icon = "🔍";
          }
          {
            __unkeyed-1 = "<M-;>";
            desc = "Command mode";
            icon = ":";
          }
        ];
      };

      home.file.".config/nvim-init/75-telescope-cmdline.lua".text = ''
        local has_telescope, telescope = pcall(require, 'telescope')
        if not has_telescope then
          return
        end

        telescope.setup({
          extensions = {
            cmdline = {
              picker = {
                layout_config = {
                  width = ${toString self.settings.picker.layout_config.width},
                  height = ${toString self.settings.picker.layout_config.height}
                }
              },
              mappings = {
                complete = '${self.settings.mappings.complete}',
                run_selection = '${self.settings.mappings.run_selection}',
                run_input = '${self.settings.mappings.run_input}'
              },
              overseer = {
                enabled = ${if self.isModuleEnabled "nvim-modules.overseer" then "true" else "false"}
              }
            }
          }
        })

        pcall(telescope.load_extension, 'cmdline')
      '';
    };
}
