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
  name = "lsp";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enablePython = true;
    enableJavaScript = true;
    enableTypeScript = true;
    enableBash = true;
    enableFish = true;
    enableNix = true;
    enableRust = true;
    enableC = true;
    enableCpp = true;
    enableLaTeX = true;
    enableRuby = true;
    enableGlobalFormatting = true;
    enableInlayHints = true;
  };

  assertions = [
    {
      assertion = !self.settings.enableLaTeX || self.isModuleEnabled "text.latex";
      message = "LSP LaTeX support requires the text.latex module to be enabled";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.lspconfig = {
          enable = true;
        };

        lsp = {
          servers = {
            "*" = {
              settings = {
                root_markers = [
                  ".git"
                  ".project"
                ];
                capabilities = {
                  textDocument = {
                    completion = {
                      completionItem = {
                        snippetSupport = true;
                      };
                    };
                  };
                };
              };
            };

            pylsp = lib.mkIf self.settings.enablePython {
              enable = true;
              package = pkgs.python3.withPackages (
                ps: with ps; [
                  python-lsp-server
                  python-lsp-black
                  pyls-isort
                  pylsp-mypy
                  black
                  isort
                  mypy
                ]
              );
              settings = {
                plugins = {
                  autopep8 = {
                    enabled = false;
                  };
                  yapf = {
                    enabled = false;
                  };
                  black = {
                    enabled = true;
                  };
                  isort = {
                    enabled = true;
                  };
                  pylsp_mypy = {
                    enabled = true;
                  };
                  pycodestyle = {
                    enabled = true;
                  };
                  pyflakes = {
                    enabled = true;
                  };
                  jedi_completion = {
                    enabled = true;
                  };
                  jedi_hover = {
                    enabled = true;
                  };
                  jedi_references = {
                    enabled = true;
                  };
                  jedi_signature_help = {
                    enabled = true;
                  };
                  jedi_symbols = {
                    enabled = true;
                  };
                };
              };
            };

            ts_ls = lib.mkIf (self.settings.enableJavaScript || self.settings.enableTypeScript) {
              enable = true;
              package = pkgs.typescript-language-server;
            };

            bashls = lib.mkIf self.settings.enableBash {
              enable = true;
              package = pkgs.bash-language-server;
            };

            fish_lsp = lib.mkIf self.settings.enableFish {
              enable = true;
              package = pkgs.fish-lsp;
            };

            nixd = lib.mkIf self.settings.enableNix {
              enable = true;
              package = pkgs.nixd;
              settings = {
                formatting = {
                  command = [ "treefmt" ];
                };
              };
            };

            rust_analyzer = lib.mkIf self.settings.enableRust {
              enable = true;
              package = pkgs.rust-analyzer;
              settings = {
                cargo = {
                  allFeatures = true;
                  loadOutDirsFromCheck = true;
                  buildScripts = {
                    enable = true;
                  };
                };
                checkOnSave = true;
                procMacro = {
                  enable = true;
                };
                inlayHints = {
                  bindingModeHints = {
                    enable = true;
                  };
                  chainingHints = {
                    enable = true;
                  };
                  closingBraceHints = {
                    enable = true;
                    minLines = 25;
                  };
                  closureReturnTypeHints = {
                    enable = "never";
                  };
                  lifetimeElisionHints = {
                    enable = "never";
                    useParameterNames = false;
                  };
                  maxLength = 25;
                  parameterHints = {
                    enable = true;
                  };
                  reborrowHints = {
                    enable = "never";
                  };
                  renderColons = true;
                  typeHints = {
                    enable = true;
                    hideClosureInitialization = false;
                    hideNamedConstructor = false;
                  };
                };
              };
            };

            clangd = lib.mkIf (self.settings.enableC || self.settings.enableCpp) {
              enable = true;
              package = pkgs.clang-tools;
              settings = {
                cmd = [
                  "clangd"
                  "--background-index"
                  "--clang-tidy"
                  "--header-insertion=iwyu"
                  "--completion-style=detailed"
                  "--function-arg-placeholders"
                  "--fallback-style=llvm"
                ];
                filetypes = [
                  "c"
                  "cpp"
                ];
                root_markers = [
                  "compile_commands.json"
                  "compile_flags.txt"
                  ".clangd"
                  ".git"
                ];
              };
            };

            texlab = lib.mkIf self.settings.enableLaTeX {
              enable = true;
              package = pkgs.texlab;
              settings = {
                texlab = {
                  build = {
                    executable = "latexmk";
                    args = [
                      "-pdf"
                      "-interaction=nonstopmode"
                      "-synctex=1"
                      "%f"
                    ];
                    onSave = false;
                  };
                  auxDirectory = ".";
                  forwardSearch = {
                    executable = null;
                    args = [ ];
                  };
                  chktex = {
                    onOpenAndSave = false;
                    onEdit = false;
                  };
                  diagnosticsDelay = 300;
                  latexFormatter = "latexindent";
                  latexindent = {
                    local = null;
                    modifyLineBreaks = false;
                  };
                };
              };
            };

            solargraph = lib.mkIf self.settings.enableRuby {
              enable = true;
            };
          };

          keymaps = [
            {
              key = "<leader>cd";
              action.__raw = "vim.diagnostic.open_float";
              options.desc = "Show diagnostics";
            }
            {
              key = "[d";
              action.__raw = "vim.diagnostic.goto_prev";
              options.desc = "Previous diagnostic";
            }
            {
              key = "]d";
              action.__raw = "vim.diagnostic.goto_next";
              options.desc = "Next diagnostic";
            }
            {
              key = "gd";
              lspBufAction = "definition";
              options.desc = "Go to definition";
            }
            {
              key = "gD";
              lspBufAction = "declaration";
              options.desc = "Go to declaration";
            }
            {
              key = "gr";
              lspBufAction = "references";
              options.desc = "Show references";
            }
            {
              key = "gi";
              lspBufAction = "implementation";
              options.desc = "Go to implementation";
            }
            {
              key = "gy";
              lspBufAction = "type_definition";
              options.desc = "Go to type definition";
            }
            {
              key = "K";
              lspBufAction = "hover";
              options.desc = "Show hover info";
            }
            {
              key = "<leader>cr";
              lspBufAction = "rename";
              options.desc = "Rename symbol";
            }
            {
              key = "<leader>ca";
              lspBufAction = "code_action";
              options.desc = "Code actions";
            }
            {
              key = "<leader>cF";
              action.__raw = ''
                function()
                  local filename = vim.fn.expand("%:t")
                  vim.cmd([[%s/\s\+$//e]])
                  vim.notify("Trailing whitespace removed from " .. filename, vim.log.levels.INFO, {
                    icon = "🧹",
                    title = "Cleanup"
                  })
                end
              '';
              options.desc = "Remove trailing whitespace";
            }
          ]
          ++ lib.optionals self.settings.enableGlobalFormatting [
            {
              key = "<leader>cf";
              action.__raw = ''
                function()
                  local filename = vim.fn.expand("%:t")
                  vim.lsp.buf.format()
                  vim.notify("File " .. filename .. " was formatted", vim.log.levels.INFO, {
                    icon = "📝",
                    title = "Formatting"
                  })
                end
              '';
              options.desc = "Format buffer";
            }
          ];

          inlayHints = lib.mkIf self.settings.enableInlayHints {
            enable = true;
          };

          onAttach = ''
            local bufname = vim.api.nvim_buf_get_name(bufnr)
            local filetype = vim.bo[bufnr].filetype
            if filetype == "man" or bufname:match("^%w+://") then
              vim.lsp.buf_detach_client(bufnr, client.id)
              return
            end

            vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

            if client.server_capabilities.documentHighlightProvider then
              local group = vim.api.nvim_create_augroup('lsp_document_highlight', { clear = false })
              vim.api.nvim_clear_autocmds({ group = group, buffer = bufnr })
              vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                group = group,
                buffer = bufnr,
                callback = vim.lsp.buf.document_highlight,
              })
              vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                group = group,
                buffer = bufnr,
                callback = vim.lsp.buf.clear_references,
              })
            end
          '';
        };

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>c";
            group = "code";
            icon = "󰅩";
          }
          {
            __unkeyed-1 = "<leader>cd";
            desc = "Show diagnostics";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>cr";
            desc = "Rename symbol";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>ca";
            desc = "Code actions";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>cf";
            desc = "Format buffer";
            icon = "";
          }
          {
            __unkeyed-1 = "<leader>cF";
            desc = "Remove trailing whitespace";
            icon = "";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["50-lsp-diagnostics"] = function()
            vim.diagnostic.config({
              float = {
                border = "single",
                source = "always",
                header = "",
                prefix = "",
              },
            })
          end
        '';
      };

    };
}
