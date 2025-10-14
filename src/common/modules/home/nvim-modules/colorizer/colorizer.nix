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
  name = "colorizer";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.colorizer = {
        enable = true;

        settings = {
          filetypes = {
            "*" = { };
          };

          user_default_options = {
            RGB = true;
            RRGGBB = true;
            names = true;
            RRGGBBAA = true;
            AARRGGBB = true;
            rgb_fn = true;
            hsl_fn = true;
            css = true;
            css_fn = true;
            mode = "background";
            tailwind = false;
            virtualtext = null;
            always_update = true;
          };
        };
      };
    };
}
