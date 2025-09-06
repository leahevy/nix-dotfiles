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
  configuration =
    context@{ config, options, ... }:
    let
      additionalLuaModules = map (mod: mod.extraLuaCode) (
        map (self.importFileCustom args) [
          "functions/auto-create-dirs.nix"
        ]
      );
    in
    {
      # See https://nix-community.github.io/nixvim/search/ for available options:
      programs.nixvim = {
        enable = true;
        package = pkgs-unstable.neovim-unwrapped;

        opts = {
          number = true;
          relativenumber = true;
          cursorline = true;

          termguicolors = true;
          mouse = "a";
          wrap = false;
          scrolloff = 8;
          sidescrolloff = 8;

          expandtab = true;
          shiftwidth = 2;
          tabstop = 2;
          autoindent = true;

          encoding = "utf-8";
          fileencoding = "utf-8";

          splitright = true;
          splitbelow = true;

          smartcase = true;
          ignorecase = true;
          hlsearch = true;
          incsearch = true;

          list = true;
          listchars = "space:·,eol:¶,tab:→ ,trail:·";

          clipboard = "unnamedplus";

          timeoutlen = 300;

          swapfile = true;
          directory = "/tmp/vim-swap-${self.user.username}";

          undofile = true;
          undodir = "${config.xdg.cacheHome}/vim-undo";
          undolevels = 1000;
          undoreload = 10000;

          backup = false;
        };

        extraConfigLua = lib.concatStringsSep "\n" (
          [
            ''
              vim.api.nvim_set_hl(0, "Whitespace", { fg = "#404040" })
              vim.api.nvim_set_hl(0, "NonText", { fg = "#404040" })

              -- Setup nvim-tree with netrw coexistence
              require("nvim-tree").setup({
                disable_netrw = false,
                hijack_netrw = false,
              })
            ''
          ]
          ++ additionalLuaModules
        );

        plugins = {
          startify = {
            enable = true;
            settings = {
              custom_header = [ "" ];
              change_to_vcs_root = true;
            };
          };

          gitgutter = {
            enable = true;
          };

          rainbow-delimiters = {
            enable = false;
          };

          airline = {
            enable = true;
          };

          web-devicons = {
            enable = true;
          };
        };

        globals = {
          mapleader = " ";
        };

        keymaps = [
          {
            key = ";";
            action = ":";
          }
          {
            key = ":";
            action = ";";
          }
          {
            key = "<leader>t";
            action = ":NvimTreeToggle<CR>";
            options.silent = true;
          }
        ];

        extraPlugins = with pkgs.vimPlugins; [
          vim-css-color
          vim-closer
          vim-smoothie
          nvim-tree-lua
        ];
      };

      home = {
        sessionVariables = {
          EDITOR = lib.mkForce "nvim";
        };

        shellAliases = {
          vim = lib.mkForce "nvim -p";
          vi = lib.mkForce "nvim -p";
          v = lib.mkForce "nvim -p";
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/nvim"
          ".local/share/nvim"
          ".local/state/nvim"
          ".cache/nvim"
          ".cache/vim-undo"
        ];
      };
    };
}
