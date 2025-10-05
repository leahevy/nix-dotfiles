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
  name = "nixvim";

  submodules = {
    common = {
      nvim-modules = {
        auto-create-dirs = true;
        auto-create-nix-files = true;
        highlight-dead-chars = true;
        jk-escape = true;
        lualine = true;
        nix-startify-logo = true;
        nvim-tree = true;
        transparency = true;
        which-key = true;
      };
    };
  };

  defaults = {
    withNeovide = false;
    terminal = "ghostty";
    manpageViewer = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      nvim_init_dir_loader = ''
        local nvim_init_dir = vim.fn.expand('~/.config/nvim-init')

        if vim.fn.isdirectory(nvim_init_dir) == 1 then
          local files = vim.fn.glob(nvim_init_dir .. '/*.lua', false, true)
          table.sort(files)
          
          for _, file in ipairs(files) do
            dofile(file)
          end
        end
      '';
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

          timeoutlen = 200;

          swapfile = true;
          directory = "/tmp/vim-swap-${self.user.username}";

          undofile = true;
          undodir = "${config.xdg.cacheHome}/vim-undo";
          undolevels = 1000;
          undoreload = 10000;

          backup = false;
        };

        extraConfigLua = nvim_init_dir_loader;

        autoCmd = [
          {
            event = [ "FileType" ];
            pattern = [ "python" ];
            callback = {
              __raw = ''
                function()
                  vim.opt_local.shiftwidth = 4
                  vim.opt_local.tabstop = 4
                  vim.opt_local.softtabstop = 4
                end
              '';
            };
          }
        ];

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
        ];
      };

      programs.neovide = lib.mkIf self.isLinux {
        enable = self.settings.withNeovide;
      };

      home = {
        sessionVariables = {
          EDITOR = lib.mkForce "nvim";
        }
        // lib.optionalAttrs self.settings.manpageViewer {
          MANPAGER = lib.mkForce "nvim +Man!";
        };

        shellAliases = {
          vim = lib.mkForce "nvim -p";
          vi = lib.mkForce "nvim -p";
          v = lib.mkForce "nvim -p";
        };
      };

      home.file.".local/bin/nvim-desktop" = lib.mkIf self.isLinux {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${self.settings.terminal} -e nvim "$@"
        '';
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

      xdg.desktopEntries = lib.optionalAttrs self.isLinux {
        "nvim" = {
          name = "Neovim wrapper";
          noDisplay = true;
        };

        "gvim" = {
          name = "GVim";
          noDisplay = true;
        };
        "vim" = {
          name = "Vim";
          noDisplay = true;
        };

        "custom-nvim" = {
          name = "Neovim";
          genericName = "Text Editor";
          comment = "Edit text files";
          exec = "${config.home.homeDirectory}/.local/bin/nvim-desktop %F";
          icon = "nvim";
          terminal = false;
          categories = [
            "Utility"
            "TextEditor"
          ];
          mimeType = [ "text/plain" ];
        };
      };
    };
}
