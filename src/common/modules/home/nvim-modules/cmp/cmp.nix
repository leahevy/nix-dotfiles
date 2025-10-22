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
  name = "cmp";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  defaults = {
    enableEmoji = true;
    enableSpell = true;
    enableGit = true;
    enableVimwikiTags = true;
    enableNvimLua = true;
    enableCmdline = true;
    enableTreesitter = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.cmp = {
          enable = true;
          autoEnableSources = true;

          settings = {
            mapping = {
              "<C-b>" = "cmp.mapping.scroll_docs(-4)";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-e>" = "cmp.mapping.abort()";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<PageUp>" = "cmp.mapping.select_prev_item({ count = 10 })";
              "<PageDown>" = "cmp.mapping.select_next_item({ count = 10 })";
            };

            sources = lib.mkMerge [
              [
                { name = "nvim_lsp"; }
                { name = "path"; }
                { name = "buffer"; }
              ]
              (lib.mkIf self.settings.enableEmoji [
                { name = "emoji"; }
              ])
              (lib.mkIf self.settings.enableSpell [
                { name = "spell"; }
              ])
              (lib.mkIf self.settings.enableGit [
                { name = "git"; }
              ])
              (lib.mkIf (self.settings.enableVimwikiTags && self.isModuleEnabled "nvim-modules.vimwiki") [
                { name = "vimwiki-tags"; }
              ])
              (lib.mkIf self.settings.enableNvimLua [
                { name = "nvim_lua"; }
              ])
              (lib.mkIf self.settings.enableTreesitter [
                { name = "treesitter"; }
              ])
            ];
          };
        };

        plugins.cmp-nvim-lsp = {
          enable = true;
        };

        plugins.cmp-buffer = {
          enable = true;
        };

        plugins.cmp-path = {
          enable = true;
        };

        plugins.cmp-emoji = lib.mkIf self.settings.enableEmoji {
          enable = true;
        };

        plugins.cmp-spell = lib.mkIf self.settings.enableSpell {
          enable = true;
        };

        plugins.cmp-git = lib.mkIf self.settings.enableGit {
          enable = true;
        };

        plugins.cmp-vimwiki-tags =
          lib.mkIf (self.settings.enableVimwikiTags && self.isModuleEnabled "nvim-modules.vimwiki")
            {
              enable = true;
            };

        plugins.cmp-nvim-lua = lib.mkIf self.settings.enableNvimLua {
          enable = true;
        };

        plugins.cmp-treesitter = lib.mkIf self.settings.enableTreesitter {
          enable = true;
        };

        plugins.cmp-cmdline = lib.mkIf self.settings.enableCmdline {
          enable = true;
        };
      };

      home.file.".config/nvim-init/39-cmp-copilot.lua".text =
        lib.mkIf (self.isModuleEnabled "nvim-modules.copilot") ''
          local cmp = require("cmp")

          vim.keymap.set("i", "<C-n>", function()
            if vim.fn.exists("*copilot#GetDisplayedSuggestion") == 1 and
               vim.fn["copilot#GetDisplayedSuggestion"]() ~= "" then
              vim.fn["copilot#Dismiss"]()
            end

            if cmp.visible() then
              cmp.select_next_item()
            else
              cmp.complete()
            end
          end, { desc = "Next completion (dismiss copilot first)" })

          vim.keymap.set("i", "<C-p>", function()
            if vim.fn.exists("*copilot#GetDisplayedSuggestion") == 1 and
               vim.fn["copilot#GetDisplayedSuggestion"]() ~= "" then
              vim.fn["copilot#Dismiss"]()
            end

            if cmp.visible() then
              cmp.select_prev_item()
            else
              cmp.complete()
            end
          end, { desc = "Previous completion (dismiss copilot first)" })
        '';

      home.file.".config/nvim-init/99-cmp-colors.lua".text = ''
        vim.api.nvim_set_hl(0, "Pmenu", { bg = "#0a0a0a", fg = "#ffffff" })
        vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#1a1a1a", fg = "#ffffff", bold = true })
        vim.api.nvim_set_hl(0, "PmenuSbar", { bg = "#0a0a0a" })
        vim.api.nvim_set_hl(0, "PmenuThumb", { bg = "#222222" })
      '';

      home.file.".config/nvim-init/40-cmp-cmdline.lua".text = lib.mkIf self.settings.enableCmdline ''
        local cmp = require("cmp")

        cmp.setup.cmdline({ "/", "?" }, {
          mapping = cmp.mapping.preset.cmdline(),
          sources = {
            { name = "buffer" }
          }
        })

        cmp.setup.cmdline(":", {
          mapping = cmp.mapping.preset.cmdline(),
          sources = cmp.config.sources({
            { name = "path" }
          }, {
            { name = "cmdline" }
          })
        })
      '';
    };
}
