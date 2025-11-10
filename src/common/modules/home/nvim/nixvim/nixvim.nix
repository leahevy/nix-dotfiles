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

  group = "nvim";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      nvim-modules = {
        blink-indent = true;
        filetypes = true;
        tiny-glimmer = true;
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
        transparency = true;
        which-key = true;
        lsp = true;
        lazygit = true;
        yazi = true;
        cmp = true;
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
        colorizer = true;
        rainbow-delimiters = true;
        web-devicons = true;
        autoclose = true;
        neoscroll = true;
        codewindow = true;
        notify = true;
        trouble = true;
      };
    };
  };

  settings = {
    withNeovide = false;
    terminal = "ghostty";
    manpageViewer = true;
    overrideThemeName = "ayu"; # Or null
    overrideThemeSettings = {
      onedark = {
        style = "deep";
      };
    };
    overrideThemeSettings = { };
    pureBlackBackground = true;
    overrideCursorHighlightColour = "#0b0b0b"; # Or null
    foreignTheme = {
      name = "eldritch";
      github = {
        owner = "eldritch-theme";
        repo = "eldritch.nvim";
        rev = "3bcdd32bd4fcca0c51616791e2a3a8fbc6039a4e";
        hash = "sha256-M2n3kWMPTIEAPXMjJd73z2+Pvf60+oUcRyJ8tKdir1Q=";
      };
      setupFunction = "eldritch";
      settings = { };
    };
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

        colorschemes =
          lib.mkIf (self.settings.foreignTheme == null && self.settings.overrideThemeName != null)
            (
              let
                settings = self.settings.overrideThemeSettings.${self.settings.overrideThemeName} or { };
              in
              {
                "${if self.settings.overrideThemeName != null then self.settings.overrideThemeName else "base16"}" =
                {
                  enable = true;
                }
                // lib.optionalAttrs (settings != { }) settings;
              }
            );

        opts = {
          number = true;
          relativenumber = true;
          cursorline = true;
          cursorcolumn = true;

          termguicolors = true;
          mouse = "a";
          wrap = true;
          linebreak = true;
          breakindent = true;
          showbreak = "↪ ";
          scrolloff = 0;
          sidescrolloff = 0;

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
          shortmess = "aoOtTIcF";
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

        extraPlugins = lib.mkIf (self.settings.foreignTheme != null) [
          (pkgs.vimUtils.buildVimPlugin {
            name = "${self.settings.foreignTheme.name}-nvim";
            src = pkgs.fetchFromGitHub {
              owner = self.settings.foreignTheme.github.owner;
              repo = self.settings.foreignTheme.github.repo;
              rev = self.settings.foreignTheme.github.rev;
              hash = self.settings.foreignTheme.github.hash;
            };
          })
        ];

        plugins = {

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
            mode = [
              "n"
              "v"
            ];
            key = "j";
            action = "gj";
            options = {
              desc = "Move down through wrapped lines";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "k";
            action = "gk";
            options = {
              desc = "Move up through wrapped lines";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "0";
            action = "g0";
            options = {
              desc = "Move to beginning of wrapped line";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "$";
            action = "g$";
            options = {
              desc = "Move to end of wrapped line";
              silent = true;
            };
          }
          {
            mode = [
              "n"
              "v"
            ];
            key = "^";
            action = "g^";
            options = {
              desc = "Move to first non-blank character of wrapped line";
              silent = true;
            };
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

      };

      home.file.".config/nvim-init/00-early-background.lua".text = ''
        vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })
        vim.cmd("highlight Normal guibg=#000000 ctermbg=black")
      '';

      home.file.".config/nvim-init/00-colorscheme.lua" =
        lib.mkIf (self.settings.foreignTheme != null || self.settings.overrideThemeName != null)
          {
            text = ''
              vim.cmd("colorscheme ${
                if self.settings.foreignTheme != null then
                  self.settings.foreignTheme.name
                else
                  self.settings.overrideThemeName
              }")
            '';
          };

      home.file.".config/nvim-init/01-foreign-theme.lua" = lib.mkIf (self.settings.foreignTheme != null) {
        text = ''
          require("${self.settings.foreignTheme.setupFunction}").setup(${builtins.toJSON self.settings.foreignTheme.settings})
        '';
      };

      home.file.".config/nvim-init/10-blinking-cursor.lua".text = ''
        vim.opt.guicursor = ""

        vim.api.nvim_create_autocmd({"VimEnter"}, {
          callback = function()
            io.write("\27[1 q")
          end
        })

        vim.api.nvim_create_autocmd({"InsertEnter"}, {
          callback = function()
            io.write("\27[5 q")
          end
        })

        vim.api.nvim_create_autocmd({"InsertLeave"}, {
          callback = function()
            io.write("\27[1 q")
          end
        })
      '';

      home.file.".config/nvim-init/04-suppress-deprecation-warnings.lua".text = ''
        vim.deprecate = function() end
      '';

      home.file.".config/nvim-init/05-disable-mouse-popup.lua".text = ''
        vim.cmd("silent! aunmenu PopUp")
        vim.cmd("autocmd! nvim.popupmenu")
      '';

      home.file.".config/nvim-init/11-insert-leave.lua".text = ''
        vim.api.nvim_create_autocmd({"InsertLeave"}, {
          callback = function()
            local col = vim.fn.col('.')
            if col > 1 and col < vim.fn.col('$') - 1 then
              vim.fn.cursor(vim.fn.line('.'), col + 1)
            end
          end
        })
      '';

      home.file.".config/nvim-init/95-pure-black-background.lua".text =
        lib.mkIf self.settings.pureBlackBackground ''
          local function fix_black_background()
            vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "NormalNC", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "SignColumn", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "LineNr", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "#000000" })

            vim.api.nvim_set_hl(0, "WinSeparator", { bg = "#000000", fg = "#000000" })
            vim.api.nvim_set_hl(0, "VertSplit", { bg = "#000000", fg = "#000000" })

            vim.api.nvim_set_hl(0, "StatusLine", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "TabLine", { bg = "#000000" })
            vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#000000" })
          end

          vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
            callback = function()
              vim.defer_fn(fix_black_background, 100)
            end,
          })
        '';

      home.file.".config/nvim-init/96-cursor-highlight-override.lua".text =
        lib.mkIf (self.settings.overrideCursorHighlightColour != null)
          ''
            local function fix_cursor_highlight()
              vim.api.nvim_set_hl(0, "CursorLine", { bg = "${self.settings.overrideCursorHighlightColour}" })
              vim.api.nvim_set_hl(0, "CursorColumn", { bg = "${self.settings.overrideCursorHighlightColour}" })
            end

            vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
              callback = function()
                vim.defer_fn(fix_cursor_highlight, 100)
              end,
            })
          '';

      programs.neovide = lib.mkIf self.isLinux {
        enable = self.settings.withNeovide;
      };

      home = {
        sessionVariables = {
          EDITOR = lib.mkForce "nvim";
          SUDO_EDITOR = lib.mkForce "nvim";
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
