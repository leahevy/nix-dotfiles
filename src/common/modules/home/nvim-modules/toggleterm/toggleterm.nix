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

  group = "nvim-modules";
  input = "common";
  namespace = "home";

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
            start_in_insert = false;
            persist_size = false;
            persist_mode = false;
            close_on_exit = true;
            auto_scroll = true;
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
            key = "<leader><leader>e";
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
          {
            mode = "t";
            key = "<C-x>";
            action = "<Esc>";
            options = {
              silent = true;
              desc = "Send ESC to terminal";
            };
          }
        ];
      };
    };
}
