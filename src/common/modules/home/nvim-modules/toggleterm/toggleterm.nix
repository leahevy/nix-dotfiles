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
  name = "toggleterm";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.toggleterm = {
          enable = true;
          settings = {
            size = 20;
            direction = "float";
            float_opts = {
              border = "curved";
              width = 120;
              height = 30;
            };
            start_in_insert = true;
            persist_size = true;
            close_on_exit = true;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>e";
            action = "<cmd>ToggleTerm<CR>";
            options = {
              silent = true;
              desc = " Toggle terminal";
            };
          }
          {
            mode = "t";
            key = "<leader>e";
            action = "<cmd>ToggleTerm<CR>";
            options = {
              silent = true;
              desc = " Toggle terminal";
            };
          }
          {
            mode = "t";
            key = "<Esc>";
            action = "<C-\\><C-n>";
            options = {
              silent = true;
              desc = "Exit terminal mode";
            };
          }
        ];
      };
    };
}
