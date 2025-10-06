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

  defaults = {
    enablePython = true;
    enableJavaScript = true;
    enableTypeScript = true;
    enableBash = true;
    enableFish = true;
    enableNix = true;
    enableGlobalFormatting = true;
    enableInlayHints = true;
  };

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
          ]
          ++ lib.optionals self.settings.enableGlobalFormatting [
            {
              key = "<leader>cf";
              lspBufAction = "format";
              options.desc = "Format buffer";
            }
          ];

          inlayHints = lib.mkIf self.settings.enableInlayHints {
            enable = true;
          };

          onAttach = ''
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
        ];
      };

    };
}
