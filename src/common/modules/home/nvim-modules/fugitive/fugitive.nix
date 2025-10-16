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
  name = "fugitive";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.fugitive = {
          enable = true;
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>gg";
            action = ":Git<CR>";
            options = {
              silent = true;
              desc = "Git status";
            };
          }
          {
            mode = "n";
            key = "<leader>gb";
            action = ":Git blame<CR>";
            options = {
              silent = true;
              desc = "Git blame";
            };
          }
          {
            mode = "n";
            key = "<leader>gd";
            action = ":Gdiffsplit<CR>";
            options = {
              silent = true;
              desc = "Git diff";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>gg";
            desc = "Git status";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gb";
            desc = "Git blame";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>gd";
            desc = "Git diff";
            icon = "";
          }
        ];
      };
    };
}
