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
        auto-save = true;
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
        telescope-cmdline = true;
        overseer = true;
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
        vimwiki = false;
        obsidian = true;
        tmuxline = false;
        vim-tmux-navigator = true;
        copilot = true;
        arrow = true;
        searchbox = true;
        grug-far = true;
        calendar = true;
        render-markdown = true;
        treesitter = true;
        zen-mode = true;
        rest = true;
        auto-session = true;
        colorizer = true;
        rainbow-delimiters = true;
        web-devicons = true;
        autoclose = true;
        twilight = true;
        neoscroll = true;
        codewindow = true;
        notify = true;
        cursorline = true;
        trouble = true;
        autosource = true;
        modicator = true;
        numbertoggle = true;
        tardis = true;
        dap = true;
        goto-preview = true;
        neotest = true;
      };
    };
  };

  settings = {
    withInitialTabs = true;
    withSocket = true;
    withData = false;
    withPerformanceOptimisations = true;
    dataPath = "/data";
    withNeovide = false;
    terminal = "ghostty";
    manpageViewer = true;
    dictionaries = [
      "en"
      "de"
    ];
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
    {
      # See https://nix-community.github.io/nixvim/search/ for available options:
      programs.nixvim = {
        enable = true;
        package = pkgs-unstable.neovim-unwrapped;

        performance = lib.mkIf self.settings.withPerformanceOptimisations {
          byteCompileLua = {
            enable = true;
            initLua = true;
            luaLib = true;
            nvimRuntime = true;
            plugins = true;
          };
          combinePlugins = {
            enable = true;
            standalonePlugins = lib.mkMerge [
              [
                "mini.nvim"
              ]
              (lib.mkIf (self.isModuleEnabled "nvim-modules.copilot") [ "copilot.vim" ])
              (lib.mkIf (self.isModuleEnabled "nvim-modules.rest") [ "rest.nvim" ])
              (lib.mkIf (self.isModuleEnabled "nvim-modules.neotest") [
                "neotest-python"
                "neotest-rust"
                "neotest-jest"
              ])
            ];
          };
        };

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
          cursorcolumn = false;

          termguicolors = true;
          mouse = "a";
          wrap = true;
          conceallevel = 2;
          concealcursor = "";
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

          spelllang = self.settings.dictionaries;
          spellfile = "${config.xdg.configHome}/nvim/spell/custom.utf-8.add";
          iskeyword = "@,48-57,_,192-255,-";
        };

        extraConfigLua = lib.mkOrder 1500 (
          lib.concatStringsSep "\n\n" (
            [
              "_G.nx_modules = _G.nx_modules or {}"

              ''
                _G.nx_modules["00-early-background"] = function()
                  vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })
                  vim.cmd("highlight Normal guibg=#000000 ctermbg=black")
                end
              ''
            ]
            ++ lib.optionals (self.settings.foreignTheme != null || self.settings.overrideThemeName != null) [
              ''
                _G.nx_modules["00-colorscheme"] = function()
                  vim.cmd("colorscheme ${
                    if self.settings.foreignTheme != null then
                      self.settings.foreignTheme.name
                    else
                      self.settings.overrideThemeName
                  }")
                end
              ''
            ]
            ++ lib.optionals (self.settings.foreignTheme != null) [
              ''
                _G.nx_modules["01-foreign-theme"] = function()
                  require("${self.settings.foreignTheme.setupFunction}").setup(${builtins.toJSON self.settings.foreignTheme.settings})
                end
              ''
            ]
            ++ [
              ''
                _G.nx_modules["04-suppress-deprecation-warnings"] = function()
                  vim.deprecate = function() end
                end
              ''

              ''
                _G.nx_modules["05-disable-mouse-popup"] = function()
                  vim.cmd("silent! aunmenu PopUp")
                  vim.cmd("autocmd! nvim.popupmenu")
                end
              ''

              ''
                _G.nx_modules["10-blinking-cursor"] = function()
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
                end
              ''

              ''
                _G.nx_modules["11-insert-leave"] = function()
                  vim.api.nvim_create_autocmd({"InsertLeave"}, {
                    callback = function()
                      local col = vim.fn.col('.')
                      if col > 1 and col < vim.fn.col('$') - 1 then
                        vim.fn.cursor(vim.fn.line('.'), col + 1)
                      end
                    end
                  })
                end
              ''
            ]
            ++ lib.optionals self.settings.pureBlackBackground [
              ''
                _G.nx_modules["95-pure-black-background"] = function()
                  local function fix_black_background()
                    vim.api.nvim_set_hl(0, "Normal", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "NormalNC", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "NormalSB", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "SignColumn", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "SignColumnSB", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "LineNr", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "CursorLineNr", { bg = "#000000" })

                    vim.api.nvim_set_hl(0, "WinSeparator", { bg = "#000000", fg = "#000000" })
                    vim.api.nvim_set_hl(0, "VertSplit", { bg = "#000000", fg = "#000000" })

                    vim.api.nvim_set_hl(0, "StatusLine", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "TabLine", { bg = "#000000" })
                    vim.api.nvim_set_hl(0, "TabLineFill", { bg = "#000000" })

                    vim.api.nvim_set_hl(0, "Pmenu", { bg = "#050505" })
                    vim.api.nvim_set_hl(0, "PmenuSel", { bg = "#04293a" })
                    vim.api.nvim_set_hl(0, "PmenuSbar", { bg = "#030303" })
                    vim.api.nvim_set_hl(0, "PmenuThumb", { bg = "#1a1a1a" })

                    vim.api.nvim_set_hl(0, "QuickFixLine", { bg = "#04293a", bold = true })
                    vim.api.nvim_set_hl(0, "qfText", { fg = "#606080" })
                    vim.api.nvim_set_hl(0, "qfLineNr", { fg = "#606080" })
                    vim.api.nvim_set_hl(0, "qfFileName", { fg = "#8080ff" })
                    vim.api.nvim_set_hl(0, "qfSeparator", { fg = "#404040" })

                    vim.api.nvim_set_hl(0, "MsgArea", { bg = "NONE", fg = "#33dd77" })
                    vim.api.nvim_set_hl(0, "Visual", { bg = "#1a4d33", fg = "#37f499" })
                  end

                  vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
                    callback = function()
                      vim.defer_fn(fix_black_background, 100)
                    end,
                  })

                  local qf_ns = vim.api.nvim_create_namespace("quickfix_highlights")
                  vim.api.nvim_set_hl(qf_ns, "CursorLine", { bg = "#031313" })

                  vim.api.nvim_create_autocmd("FileType", {
                    pattern = "qf",
                    callback = function()
                      vim.wo.winhighlight = "CursorLine:CursorLine,Normal:NormalSB,SignColumn:SignColumnSB"
                      vim.api.nvim_win_set_hl_ns(0, qf_ns)
                    end,
                  })
                end
              ''
            ]
            ++ lib.optionals (self.settings.overrideCursorHighlightColour != null) [
              ''
                _G.nx_modules["96-cursor-highlight-override"] = function()
                  local function fix_cursor_highlight()
                    vim.api.nvim_set_hl(0, "CursorLine", { underline = true, sp = "${self.settings.overrideCursorHighlightColour}" })
                    vim.api.nvim_set_hl(0, "CursorColumn", { bg = "${self.settings.overrideCursorHighlightColour}" })
                  end

                  vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
                    callback = function()
                      vim.defer_fn(fix_cursor_highlight, 100)
                    end,
                  })
                end
              ''
            ]
            ++ lib.optionals self.settings.withSocket [
              ''
                _G.nx_modules["97-socket-notification"] = function()
                  vim.api.nvim_create_autocmd("VimEnter", {
                    once = true,
                    callback = function()
                      vim.defer_fn(function()
                        local socket_name = vim.v.servername
                        if socket_name and socket_name ~= "" then
                          if not string.match(socket_name, "^/tmp/") then
                            local socket_exists = vim.fn.filereadable(socket_name) == 1
                            if socket_exists then
                              local absolute_path = vim.fn.fnamemodify(socket_name, ":p")
                              vim.notify("🖥️ Server started at " .. absolute_path, vim.log.levels.INFO, {
                                title = "Neovim Server",
                                timeout = 3000
                              })
                            end
                          end
                        end
                      end, 500)
                    end,
                  })
                end
              ''
            ]
            ++ [
              ''
                local init_start_time = vim.loop.hrtime()

                local modules = _G.nx_modules or {}
                local sorted_keys = {}
                for name, _ in pairs(modules) do
                  table.insert(sorted_keys, name)
                end
                table.sort(sorted_keys)

                local loaded_count = 0
                local failed_count = 0
                for _, name in ipairs(sorted_keys) do
                  local success, err = pcall(modules[name])
                  if success then
                    loaded_count = loaded_count + 1
                  else
                    failed_count = failed_count + 1
                    vim.schedule(function()
                      vim.defer_fn(function()
                        vim.notify("❌ Module " .. name .. " failed: " .. err, vim.log.levels.ERROR, { title = "Module Loading" })
                      end, 200)
                    end)
                  end
                end

                if failed_count > 0 then
                  vim.schedule(function()
                    vim.defer_fn(function()
                        vim.notify("⚠️ Loaded " .. loaded_count .. "/" .. #sorted_keys .. " modules with " .. failed_count .. " failures", vim.log.levels.WARN, { title = "Neovim" })
                    end, 100)
                  end)
                else
                  vim.schedule(function()
                    print("Neovim: Loaded " .. loaded_count .. "/" .. #sorted_keys .. " modules")
                  end)
                end

                local init_end_time = vim.loop.hrtime()
                local init_duration_ms = (init_end_time - init_start_time) / 1000000
                vim.schedule(function()
                  print(string.format("Neovim: Module initialization took %.2fms", init_duration_ms))
                end)

                _G.nx_modules = nil
              ''
            ]
          )
        );

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
              __unkeyed-1 = "<leader>B";
              desc = "Close all other buffers";
              icon = "🧹";
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
            {
              __unkeyed-1 = "<leader>E";
              desc = "Save current buffer";
              icon = "💾";
            }
            {
              __unkeyed-1 = "<leader>fs";
              desc = "Toggle spell check";
              icon = "📝";
            }
          ];
        };

        globals = {
          mapleader = " ";
          maplocalleader = "\\";
        };

        keymaps = [
          {
            key = ":";
            action = ";";
          }
          {
            mode = "v";
            key = ";";
            action = ":";
          }
        ]
        ++ lib.optionals (!(self.isModuleEnabled "nvim-modules.telescope-cmdline")) [
          {
            mode = "n";
            key = ";";
            action = ":";
          }
        ]
        ++ [
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
            key = "<C-D>";
            action.__raw = ''
              function()
                local now = vim.loop.now()
                if _G.scroll_processing or (_G.last_scroll_time and now - _G.last_scroll_time < 50) then
                  return
                end
                _G.scroll_processing = true
                _G.last_scroll_time = now

                local win_height = vim.api.nvim_win_get_height(0)
                local cursor_line = vim.fn.line('.')
                local win_top = vim.fn.line('w0')
                local win_bottom = vim.fn.line('w$')
                local lines_to_move = math.floor(win_height / 7)
                local edge_threshold = 10

                if cursor_line == win_bottom then
                  vim.cmd('normal! ' .. lines_to_move .. 'j')
                  vim.cmd('normal! zz')
                  _G.scroll_processing = false
                else
                  vim.cmd('normal! ' .. lines_to_move .. 'j')
                  _G.scroll_processing = false
                end
              end
            '';
            options = {
              desc = "Smart scroll down";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<C-U>";
            action.__raw = ''
              function()
                local now = vim.loop.now()
                if _G.scroll_processing or (_G.last_scroll_time and now - _G.last_scroll_time < 50) then
                  return
                end
                _G.scroll_processing = true
                _G.last_scroll_time = now

                local win_height = vim.api.nvim_win_get_height(0)
                local cursor_line = vim.fn.line('.')
                local win_top = vim.fn.line('w0')
                local win_bottom = vim.fn.line('w$')
                local lines_to_move = math.floor(win_height / 7)
                local edge_threshold = 10

                if cursor_line == win_top then
                  vim.cmd('normal! ' .. lines_to_move .. 'k')
                  vim.cmd('normal! zz')
                  _G.scroll_processing = false
                else
                  vim.cmd('normal! ' .. lines_to_move .. 'k')
                  _G.scroll_processing = false
                end
              end
            '';
            options = {
              desc = "Smart scroll up";
              silent = true;
            };
          }
          {
            mode = "v";
            key = "<C-D>";
            action.__raw = ''
              function()
                local now = vim.loop.now()
                if _G.scroll_processing or (_G.last_scroll_time and now - _G.last_scroll_time < 50) then
                  return
                end
                _G.scroll_processing = true
                _G.last_scroll_time = now

                local win_height = vim.api.nvim_win_get_height(0)
                local cursor_line = vim.fn.line('.')
                local win_top = vim.fn.line('w0')
                local win_bottom = vim.fn.line('w$')
                local lines_to_move = math.floor(win_height / 7)
                local edge_threshold = 10

                if cursor_line == win_bottom then
                  vim.cmd('normal! ' .. lines_to_move .. 'j')
                  vim.cmd('normal! zz')
                  _G.scroll_processing = false
                else
                  vim.cmd('normal! ' .. lines_to_move .. 'j')
                  _G.scroll_processing = false
                end
              end
            '';
            options = {
              desc = "Smart scroll down";
              silent = true;
            };
          }
          {
            mode = "v";
            key = "<C-U>";
            action.__raw = ''
              function()
                local now = vim.loop.now()
                if _G.scroll_processing or (_G.last_scroll_time and now - _G.last_scroll_time < 50) then
                  return
                end
                _G.scroll_processing = true
                _G.last_scroll_time = now

                local win_height = vim.api.nvim_win_get_height(0)
                local cursor_line = vim.fn.line('.')
                local win_top = vim.fn.line('w0')
                local win_bottom = vim.fn.line('w$')
                local lines_to_move = math.floor(win_height / 7)
                local edge_threshold = 10

                if cursor_line == win_top then
                  vim.cmd('normal! ' .. lines_to_move .. 'k')
                  vim.cmd('normal! zz')
                  _G.scroll_processing = false
                else
                  vim.cmd('normal! ' .. lines_to_move .. 'k')
                  _G.scroll_processing = false
                end
              end
            '';
            options = {
              desc = "Smart scroll up";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>n";
            action.__raw = ''
              function()
                vim.cmd("tabnew | Dashboard")
                vim.notify("📄 New tab created", vim.log.levels.INFO, {
                  title = "Tab"
                })
              end
            '';
            options = {
              desc = "New tab";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>q";
            action.__raw = ''
              function()
                local tab_count = vim.fn.tabpagenr('$')
                if tab_count == 1 then
                  vim.cmd("quit")
                else
                  vim.cmd("tabclose")
                  vim.notify("❌ Tab closed", vim.log.levels.INFO, {
                    title = "Tab"
                  })
                end
              end
            '';
            options = {
              desc = "Close tab";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>v";
            action.__raw = ''
              function()
                local filename = vim.fn.expand("%:t")
                vim.cmd("vsplit")
                vim.notify("↔️ Split vertically: " .. filename, vim.log.levels.INFO, {
                  title = "Split"
                })
              end
            '';
            options = {
              desc = "Split vertical";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>h";
            action.__raw = ''
              function()
                local filename = vim.fn.expand("%:t")
                vim.cmd("split")
                vim.notify("↕️ Split horizontally: " .. filename, vim.log.levels.INFO, {
                  title = "Split"
                })
              end
            '';
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
            key = "<leader>B";
            action.__raw = ''
              function()
                local current_buf = vim.api.nvim_get_current_buf()
                local bufname = vim.api.nvim_buf_get_name(current_buf)

                if bufname == "" or vim.bo[current_buf].buftype ~= "" then
                  vim.notify("❌ Current buffer is not a file", vim.log.levels.WARN, {
                    title = "Close Other Buffers"
                  })
                  return
                end

                local buffers = vim.api.nvim_list_bufs()
                local closed_count = 0

                for _, buf in ipairs(buffers) do
                  if buf ~= current_buf and vim.api.nvim_buf_is_valid(buf) then
                    local buf_modified = vim.bo[buf].modified
                    local bufname_other = vim.api.nvim_buf_get_name(buf)
                    local is_listed = vim.bo[buf].buflisted

                    if not buf_modified and is_listed then
                      vim.api.nvim_buf_delete(buf, { force = false })
                      closed_count = closed_count + 1
                    end
                  end
                end

                local filename = vim.fn.fnamemodify(bufname, ":t")
                if closed_count == 0 then
                  vim.notify("💡 No other buffers to close", vim.log.levels.INFO, {
                    title = "Close Other Buffers"
                  })
                else
                  vim.notify("🗑️ Closed " .. closed_count .. " buffers, kept: " .. filename, vim.log.levels.INFO, {
                    title = "Close Other Buffers"
                  })
                end
              end
            '';
            options = {
              desc = "Close all other buffers";
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
            key = "<leader>E";
            action = "<cmd>w<CR>";
            options = {
              desc = "Save current buffer";
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
            action.__raw = ''
              function()
                vim.cmd("wa")
                local buf_count = #vim.api.nvim_list_bufs()
                vim.notify("💾 All " .. buf_count .. " buffers saved", vim.log.levels.INFO, {
                  title = "Save"
                })
              end
            '';
            options = {
              desc = "Save all";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>fs";
            action.__raw = ''
              function()
                vim.opt_local.spell = not vim.opt_local.spell:get()
                local status = vim.opt_local.spell:get() and "enabled" or "disabled"
                local emoji = vim.opt_local.spell:get() and "✅" or "❌"
                vim.notify(emoji .. " Spell check " .. status, vim.log.levels.INFO, {
                  title = "Spell Check"
                })
              end
            '';
            options = {
              desc = "Toggle spell check";
              silent = true;
            };
          }
        ];
      };

      programs.neovide = lib.mkIf self.isLinux {
        enable = self.settings.withNeovide;
      };

      home = {
        sessionVariables = {
          EDITOR = lib.mkForce "nvim-run";
          SUDO_EDITOR = lib.mkForce "nvim-run";
        }
        // lib.optionalAttrs self.settings.manpageViewer {
          MANPAGER = lib.mkForce "nvim-run +Man!";
        };

        shellAliases = {
          nvim = lib.mkForce "nvim-run";
          vim = lib.mkForce "nvim-run";
          vi = lib.mkForce "nvim-run";
          v = lib.mkForce "nvim-run";
        };
      };

      home.file.".local/bin/vim" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${config.programs.nixvim.build.package}/bin/nvim "$@"
        '';
      };

      home.file.".local/bin/nvim-run" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          ADDITIONAL_ARGS=()

          ${lib.optionalString self.settings.withInitialTabs ''
            ADDITIONAL_ARGS+=("-p")
          ''}

          ${lib.optionalString self.settings.withSocket ''
            SOCKET_NAME=""
            USE_TMP_SOCKET=false
            ${
              if self.isLinux then
                ''
                  if [[ "$PWD" == /home/* ]]; then
                    SOCKET_NAME="./.nvim.socket"
                  fi
                ''
              else if self.isDarwin then
                ''
                  if [[ "$PWD" == /Users/* ]]; then
                    SOCKET_NAME="./.nvim.socket"
                  fi
                ''
              else
                ''
                  SOCKET_NAME="/tmp/nvim-${self.user.username}.socket"
                  USE_TMP_SOCKET=true
                ''
            }
            ${lib.optionalString (!self.user.isStandalone && self.settings.withData) ''
              if [[ "$PWD" == ${self.settings.dataPath}/* ]]; then
                SOCKET_NAME="./.nvim.socket"
              fi
            ''}

            if [[ -z "$SOCKET_NAME" || ! -e "$(dirname "$SOCKET_NAME")" || ! -w "$(dirname "$SOCKET_NAME")" ]]; then
              SOCKET_NAME="/tmp/nvim-${self.user.username}.socket"
              USE_TMP_SOCKET=true
            fi

            if [[ -e "$SOCKET_NAME" ]]; then
              if [[ "$USE_TMP_SOCKET" != "true" ]]; then
                rm -f "$SOCKET_NAME"
                ADDITIONAL_ARGS+=("--listen" "$SOCKET_NAME")
              fi
            else
              ADDITIONAL_ARGS+=("--listen" "$SOCKET_NAME")
            fi
          ''}

          if [ ''${#ADDITIONAL_ARGS[@]} -gt 0 ]; then
            exec ${config.programs.nixvim.build.package}/bin/nvim "''${ADDITIONAL_ARGS[@]}" "$@"
          else
            exec ${config.programs.nixvim.build.package}/bin/nvim "$@"
          fi
        '';
      };

      home.file.".local/bin/nvim-desktop" = lib.mkIf self.isLinux {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${self.settings.terminal} -e nvim-run "$@"
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
