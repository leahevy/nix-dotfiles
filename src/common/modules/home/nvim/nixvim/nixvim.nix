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
        template = true;
        highlight-dead-chars = true;
        jk-escape = true;
        vim-airline = true;
        lualine = false;
        startify = false;
        telescope = true;
        gitgutter = true;
        fugitive = true;
        toggleterm = true;
        dashboard = true;
        nvim-tree = true;
        transparency = false;
        which-key = true;
        lsp = true;
        project = true;
        vimwiki = true;
        tmuxline = false;
        vim-tmux-navigator = true;
        copilot = true;
        searchbox = true;
        grug-far = true;
        calendar = true;
        render-markdown = true;
        treesitter = true;
        rest = true;
        auto-session = true;
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
          rainbow-delimiters = {
            enable = false;
          };

          web-devicons = {
            enable = true;
          };

          which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
            {
              __unkeyed-1 = "<leader>n";
              desc = "New Tab";
              icon = "";
            }
            {
              __unkeyed-1 = "<leader>h";
              desc = "Split Horizontal";
              icon = "—";
            }
            {
              __unkeyed-1 = "<leader>v";
              desc = "Split Vertical";
              icon = "|";
            }
            {
              __unkeyed-1 = "<leader>q";
              desc = "Close Tab";
              icon = "";
            }
            {
              __unkeyed-1 = "<leader>[";
              desc = "Previous Buffer";
              icon = "◀";
            }
            {
              __unkeyed-1 = "<leader>]";
              desc = "Next Buffer";
              icon = "▶";
            }
            {
              __unkeyed-1 = "<leader>Q";
              group = "Quit";
              icon = "󰗼";
            }
            {
              __unkeyed-1 = "<leader>QQ";
              desc = "Save all and quit";
              icon = "󰗼";
            }
            {
              __unkeyed-1 = "<leader>QX";
              desc = "Quit without saving";
              icon = "󱎘";
            }
            {
              __unkeyed-1 = "<leader>W";
              desc = "Save all";
              icon = "💾";
            }
          ];
        };

        globals = {
          mapleader = " ";
          maplocalleader = "\\";
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
            mode = "n";
            key = "<leader>n";
            action = "<cmd>tabnew | Dashboard<cr>";
            options = {
              desc = "New tab";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>q";
            action = "<cmd>if tabpagenr('$') == 1 | quit | else | tabclose | endif<cr>";
            options = {
              desc = "Close tab";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>v";
            action = "<cmd>vsplit<CR>";
            options = {
              desc = "Split vertical";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>h";
            action = "<cmd>split<CR>";
            options = {
              desc = "Split horizontal";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>[";
            action = "<cmd>bprevious<CR>";
            options = {
              desc = "Previous buffer";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>]";
            action = "<cmd>bnext<CR>";
            options = {
              desc = "Next buffer";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>QQ";
            action = "<cmd>wqa<CR>";
            options = {
              desc = "Save all and quit";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>QX";
            action = "<cmd>qa!<CR>";
            options = {
              desc = "Quit without saving";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>W";
            action = "<cmd>wa<CR>";
            options = {
              desc = "Save all";
              silent = true;
            };
          }
        ];

        extraPlugins = with pkgs.vimPlugins; [
          vim-css-color
          vim-closer
          vim-smoothie
        ];
      };

      home.file.".config/nvim-init/95-colour-override.lua".text = ''
        local function fix_colours()
          vim.api.nvim_set_hl(0, "WinSeparator", { bg = "#000000", fg = "#000000" })
          vim.api.nvim_set_hl(0, "VertSplit", { bg = "#000000", fg = "#000000" })
        end

        vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
          callback = function()
            vim.defer_fn(fix_colours, 100)
          end,
        })
      '';

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

      home.activation.nvim-timestamp = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ${self.user.home}/.config/nvim || true
        run touch ${self.user.home}/.config/nvim/timestamp || true
      '';

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
