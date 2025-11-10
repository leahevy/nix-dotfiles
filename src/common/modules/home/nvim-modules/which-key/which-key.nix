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
let
  programmingFileTypes = [
    "c"
    "cpp"
    "h"
    "hpp"
    "python"
    "javascript"
    "typescript"
    "jsx"
    "tsx"
    "java"
    "rust"
    "go"
    "php"
    "ruby"
    "perl"
    "lua"
    "vim"
    "sh"
    "bash"
    "zsh"
    "fish"
    "nix"
  ];
in
{
  name = "which-key";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    delay = 400;
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
          filter.__raw = ''
            function(mapping)
              return mapping.group ~= nil or (mapping.desc ~= nil and mapping.desc ~= "")
            end
          '';

          icons = {
            mappings = true;
            colors = true;
          };

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
              __unkeyed-1 = "#";
              desc = "Search word backward";
              mode = "v";
            }
            {
              __unkeyed-1 = "*";
              desc = "Search word forward";
              mode = "v";
            }
            {
              __unkeyed-1 = "@";
              desc = "Execute macro";
              mode = "v";
            }
            {
              __unkeyed-1 = "<C-B>";
              desc = "Smooth page up";
              mode = "v";
            }
            {
              __unkeyed-1 = "<C-D>";
              desc = "Smooth half page down";
              mode = "v";
            }
            {
              __unkeyed-1 = "<C-F>";
              desc = "Smooth page down";
              mode = "v";
            }
            {
              __unkeyed-1 = "<C-U>";
              desc = "Smooth half page up";
              mode = "v";
            }
            {
              __unkeyed-1 = "<PageDown>";
              desc = "Smooth page down";
              mode = "v";
            }
            {
              __unkeyed-1 = "<PageUp>";
              desc = "Smooth page up";
              mode = "v";
            }
            {
              __unkeyed-1 = "<S-Down>";
              desc = "Smooth shift down";
              mode = "v";
            }
            {
              __unkeyed-1 = "<S-Up>";
              desc = "Smooth shift up";
              mode = "v";
            }
          ];

          win = {
            border = "rounded";
            padding = [
              1
              2
            ];
          };

          keys = {
            scroll_down = "<C-PageDown>";
            scroll_up = "<C-PageUp>";
          };

          show_help = self.settings.showHelp;
          show_keys = self.settings.showKeys;
        };
      };

      programs.nixvim.autoCmd = [
        {
          event = [ "FileType" ];
          pattern = programmingFileTypes;
          callback.__raw = ''
            function()
              local ft = vim.bo.filetype
              if ft ~= "vimwiki" then
                require("which-key").add({
                  { "[[", desc = "Previous function/class", buffer = 0 },
                  { "]]", desc = "Next function/class", buffer = 0 },
                })
              end
            end
          '';
        }
        {
          event = [ "FileType" ];
          pattern = [ "python" ];
          callback.__raw = ''
            function()
              require("which-key").add({
                { "[m", desc = "Previous method", buffer = 0 },
                { "]m", desc = "Next method", buffer = 0 },
                { "[M", desc = "Previous class/method (context)", buffer = 0 },
                { "]M", desc = "Next class/method (context)", buffer = 0 },
                { "[]", desc = "Previous class/function end", buffer = 0 },
                { "][", desc = "Next class/function end", buffer = 0 },
              })
            end
          '';
        }
        {
          event = [ "BufLeave" ];
          pattern = programmingFileTypes;
          callback.__raw = ''
            function()
              pcall(require("which-key").clear, { buffer = 0 })
            end
          '';
        }
      ];
    };
}
