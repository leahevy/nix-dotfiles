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

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.neoscroll = {
        enable = true;

        settings = {
          mappings = [
            "<C-u>"
            "<C-d>"
          ];
          hide_cursor = true;
          stop_eof = true;
          respect_scrolloff = false;
          cursor_scrolls_alone = true;
          easing_function = "sine";
          performance_mode = false;
        };
      };
    };
}
