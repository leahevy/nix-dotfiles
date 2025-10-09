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

        autoCmd = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            event = [
              "BufEnter"
              "FileType"
            ];
            pattern = [
              "*.md"
              "vimwiki"
            ];
            callback.__raw = ''
              function()
                if vim.bo.filetype == "vimwiki" then
                  require("which-key").add({
                    { "<leader>wr", desc = "Rename wiki file", buffer = 0 },
                    { "<leader>wd", desc = "Delete wiki file", buffer = 0 },
                    { "<leader>wn", desc = "Go to wiki file", buffer = 0 },
                    { "<leader>wh", desc = "Convert to HTML", buffer = 0 },
                    { "<leader>whh", desc = "Convert to HTML and browse", buffer = 0 },
                    { "<leader>wc", desc = "Colorize wiki", buffer = 0 },
                    { "<CR>", desc = "Follow wiki link", buffer = 0 },
                    { "<Tab>", desc = "Next wiki link", buffer = 0 },
                    { "+", desc = "Normalize wiki link", buffer = 0 },
                    { "-", desc = "Remove header level", buffer = 0 },
                    { "=", desc = "Add header level", buffer = 0 },
                    { "O", desc = "List open above", buffer = 0 },
                    { "[[", desc = "Previous header", buffer = 0 },
                    { "]]", desc = "Next header", buffer = 0 },
                    { "[=", desc = "Previous sibling header", buffer = 0 },
                    { "]=", desc = "Next sibling header", buffer = 0 },
                    { "[u", desc = "Parent header", buffer = 0 },
                  })
                end
              end
            '';
          }
          {
            event = [ "BufLeave" ];
            pattern = [ "*.md" ];
            callback.__raw = ''
              function()
                if vim.bo.filetype == "vimwiki" then
                  pcall(require("which-key").clear, { buffer = 0 })
                end
              end
            '';
          }
        ];
      };

      home.file.".local/bin/vimwiki-migrate-index" = {
        source = self.file "vimwiki-migrate-index.py";
        executable = true;
      };
    };
}
