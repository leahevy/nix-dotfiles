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
  name = "which-key";

  defaults = {
    delay = 600;
    showHelp = true;
    showKeys = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.which-key = {
        enable = true;
        settings = {
          delay = self.settings.delay;
          expand = 1;
          notify = false;
          preset = "modern";

          replace = {
            desc = [
              [
                "<space>"
                "SPC"
              ]
              [
                "<leader>"
                "SPC"
              ]
              [
                "<cr>"
                "RET"
              ]
              [
                "<tab>"
                "TAB"
              ]
            ];
          };

          spec = [
            {
              __unkeyed-1 = "<leader>f";
              group = "file";
            }
            {
              __unkeyed-1 = "<leader>c";
              group = "code";
            }
            {
              __unkeyed-1 = "<leader>g";
              group = "git";
            }
            {
              __unkeyed-1 = "<leader>s";
              group = "search";
            }
            {
              __unkeyed-1 = "<leader>w";
              group = "window";
            }
            {
              __unkeyed-1 = "<leader>b";
              group = "buffer";
            }
            {
              __unkeyed-1 = "<leader>t";
              desc = "Toggle NvimTree";
            }
          ];

          win = {
            border = "rounded";
            padding = [
              1
              2
            ];
          };

          show_help = self.settings.showHelp;
          show_keys = self.settings.showKeys;
        };
      };
    };
}
