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
  name = "neoscroll";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.neoscroll = {
          enable = true;

          settings = {
            mappings = [ ];
            hide_cursor = true;
            stop_eof = true;
            respect_scrolloff = false;
            cursor_scrolls_alone = true;
            easing_function = "sine";
            performance_mode = false;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<C-f>";
            action.__raw = "function() require('neoscroll').ctrl_d({duration = 250}) end";
            options = {
              desc = "Half page down (neoscroll)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<C-b>";
            action.__raw = "function() require('neoscroll').ctrl_u({duration = 250}) end";
            options = {
              desc = "Half page up (neoscroll)";
              silent = true;
            };
          }
        ];
      };
    };
}
