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
  name = "vimwiki";

  defaults = {
    wikiPath = "~/.local/share/nvim/wiki/";
  };

  configuration =
    context@{ config, options, ... }:
    let
      normalizedWikiPath =
        let
          path = self.settings.wikiPath;
          homePrefix = "$HOME";
        in
        if lib.hasPrefix homePrefix path then "~" + lib.removePrefix homePrefix path else path;
    in
    {
      programs.nixvim = {
        plugins.vimwiki = {
          enable = true;
          settings = {
            list = [
              {
                path = normalizedWikiPath;
                syntax = "markdown";
                ext = ".md";
              }
            ];
            global_ext = 1;
            use_calendar = 1;
            auto_header = 1;
            conceallevel = 2;
            folding = "expr";
          };
        };

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>w";
            group = "wiki";
            icon = "󰖬";
          }
          {
            __unkeyed-1 = "<leader>ww";
            desc = "Wiki index";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wi";
            desc = "Diary index";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>wt";
            desc = "Wiki in new tab";
            icon = "󰓩";
          }
          {
            __unkeyed-1 = "<leader>ws";
            desc = "Wiki select";
            icon = "󰓩";
          }
          {
            __unkeyed-1 = "<leader>wd";
            desc = "Wiki diary";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>w";
            desc = "Make diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>y";
            desc = "Make yesterday diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>t";
            desc = "Make diary note (tab)";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>m";
            desc = "Make tomorrow diary note";
            icon = "󰃭";
          }
          {
            __unkeyed-1 = "<leader>w<leader>i";
            desc = "Make diary links";
            icon = "󰃭";
          }
        ];
      };
    };
}
