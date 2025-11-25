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

  settings = {
    baseSourcesToEnable = [
      "nvim_lsp"
      "path"
      "buffer"
    ];

    additionalSourcesToEnable = [
      "emoji"
      "spell"
      "git"
      "vimwiki-tags"
      "nvim_lua"
      "treesitter"
    ];

    autoCompleteSources = [
      "nvim_lsp"
      "treesitter"
    ];

    enableCmdline = true;
    enableAutoComplete = true;
    globalAutoCompleteEnabled = true;
    excludeFiletypesFromAutoComplete = [
      "help"
      "dashboard"
      "alpha"
      "startify"
      "NvimTree"
      "neo-tree"
      "netrw"
      "telescope"
      "TelescopePrompt"
      "TelescopeResults"
      "trouble"
      "Trouble"
      "toggleterm"
      "terminal"
      "lspinfo"
      "checkhealth"
      "man"
      "qf"
      "quickfix"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "notify"
      "yazi"
      "Codewindow"
      "lazy"
      "mason"
      "prompt"
      "nofile"
      "nowrite"
      "markdown"
      "text"
      "vimwiki"
      ""
    ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      mkSource = name: { inherit name; };

      allEnabledSources = self.settings.baseSourcesToEnable ++ self.settings.additionalSourcesToEnable;

      mkAllSources = map mkSource allEnabledSources;
      mkAutoSources = map mkSource self.settings.autoCompleteSources;

      mkLuaSourceArray = sources: lib.concatMapStringsSep ", " (s: ''{ name = "${s}" }'') sources;
    in
    {
      programs.nixvim = {
        plugins = lib.mkMerge (
          [
            {
              cmp = {
                enable = true;
                autoEnableSources = false;

                settings = lib.mkMerge [
                  {
                    performance = {
                      debounce = 60;
                      throttle = 30;
                      fetching_timeout = 500;
                    };

                    matching = {
                      disallow_fullfuzzy_matching = true;
                    };

                    formatting = {
                      expandable_indicator = false;
                    };

                    window = {
                      completion = {
                        border = "single";
                        side_padding = 1;
                        scrollbar = true;
                      };
                    };

                    mapping = lib.mkMerge [
                      {
                        "<C-b>" = "cmp.mapping.scroll_docs(-4)";
                        "<C-f>" = "cmp.mapping.scroll_docs(4)";
                        "<C-Space>" = "cmp.mapping.complete()";
                        "<C-e>" = "cmp.mapping.abort()";
                        "<CR>" = "cmp.mapping.confirm({ select = true })";
                        "<PageUp>" = "cmp.mapping.select_prev_item({ count = 10 })";
                        "<PageDown>" = "cmp.mapping.select_next_item({ count = 10 })";
                      }
                      (lib.mkIf (!self.isModuleEnabled "nvim-modules.copilot") {
                        "<C-n>" =
                          "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_next_item() else cmp.complete() end end, { 'i', 's' })";
                        "<C-p>" =
                          "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_prev_item() else cmp.complete() end end, { 'i', 's' })";
                      })
                    ];

                    sources = if self.settings.enableAutoComplete then mkAutoSources else mkAllSources;
                  }
                  (lib.mkIf (!self.settings.enableAutoComplete) {
                    completion = {
                      autocomplete = false;
                    };
                  })
                ];
              };
            }
          ]
          ++ (map (source: {
            "cmp-${builtins.replaceStrings [ "_" ] [ "-" ] source}" = {
              enable = true;
            };
          }) allEnabledSources)
          ++ lib.optional self.settings.enableCmdline {
            cmp-cmdline = {
              enable = true;
            };
          }
          ++ lib.optional (self.isModuleEnabled "nvim-modules.which-key") {
            which-key.settings.spec = [
              {
                __unkeyed-1 = "<leader>l";
                desc = "Toggle auto-completion";
                icon = "💬";
              }
            ];
          }
        );

        keymaps = lib.mkMerge [
          (lib.mkIf self.settings.enableAutoComplete [
            {
              mode = "i";
              key = "<C-x>";
              action.__raw = ''
                function()
                  local cmp = require('cmp')
                  local all_sources_config = {
                    config = {
                      sources = {
                        ${mkLuaSourceArray allEnabledSources}
                      }
                    }
                  }

                  if cmp.visible() then
                    cmp.abort()
                  end

                  cmp.complete(all_sources_config)
                end
              '';
              options = {
                desc = "Manual completion with all sources";
                silent = true;
              };
            }
            {
              mode = "i";
              key = "<C-z>";
              action.__raw = ''
                function()
                  local cmp = require('cmp')
                  local auto_sources_config = {
                    config = {
                      sources = {
                        ${mkLuaSourceArray self.settings.autoCompleteSources}
                      }
                    }
                  }

                  if cmp.visible() then
                    cmp.abort()
                  end

                  cmp.complete(auto_sources_config)
                end
              '';
              options = {
                desc = "Manual completion with auto sources only";
                silent = true;
              };
            }
          ])
          [
            {
              mode = "n";
              key = "<C-z>";
              action = "<Nop>";
              options = {
                desc = "Disabled - use <C-z> in insert mode for completion";
                silent = true;
              };
            }
            {
              mode = "n";
              key = "<leader>l";
              action.__raw = ''
                function()
                  vim.g.cmp_global_enabled = not vim.g.cmp_global_enabled
                  require('cmp').setup.buffer { enabled = vim.g.cmp_global_enabled }
                  local icon = vim.g.cmp_global_enabled and "✅" or "❌"
                  local status = vim.g.cmp_global_enabled and "Feature enabled" or "Feature disabled"
                  vim.notify(icon .. " " .. status, vim.log.levels.INFO, {
                    title = "Auto-Completion"
                  })
                end
              '';
              options = {
                desc = "Toggle auto-completion";
                silent = true;
              };
            }
          ]
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}

          _G.nx_modules["38-cmp-global"] = function()
            vim.opt.complete = ""
            vim.opt.completefunc = ""
            vim.lsp.omnifunc = function() return {} end

            vim.g.cmp_global_enabled = ${if self.settings.globalAutoCompleteEnabled then "true" else "false"}

            local excluded_filetypes = {
              ${lib.concatMapStringsSep ", " (ft: "\"${ft}\"") self.settings.excludeFiletypesFromAutoComplete}
            }

            local function should_disable_for_filetype(filetype)
              for _, excluded_ft in ipairs(excluded_filetypes) do
                if filetype == excluded_ft then
                  return true
                end
              end
              return false
            end

            local function apply_cmp_to_buffer()
              local cmp = require('cmp')
              local filetype = vim.bo.filetype

              if should_disable_for_filetype(filetype) then
                cmp.setup.buffer({ enabled = false })
              else
                cmp.setup.buffer({ enabled = vim.g.cmp_global_enabled })
              end
            end

            vim.api.nvim_create_augroup('CmpGlobalToggle', { clear = true })
            vim.api.nvim_create_autocmd({ 'BufEnter', 'BufNew', 'FileType' }, {
              group = 'CmpGlobalToggle',
              callback = function()
                vim.schedule(function()
                  apply_cmp_to_buffer()
                  vim.opt_local.completefunc = ""
                  vim.opt_local.omnifunc = ""
                end)
              end,
            })

            vim.api.nvim_create_autocmd('LspAttach', {
              group = 'CmpGlobalToggle',
              callback = function()
                vim.opt_local.omnifunc = ""
              end,
            })
          end

          ${if !(self.isModuleEnabled "nvim-modules.copilot") then "--[[" else ""}
          _G.nx_modules["39-cmp-copilot"] = function()
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
          end
          ${if !(self.isModuleEnabled "nvim-modules.copilot") then "]]" else ""}

          ${if !(self.settings.enableCmdline) then "--[[" else ""}
          _G.nx_modules["40-cmp-cmdline"] = function()
            local cmp = require("cmp")

            vim.keymap.set('c', '<C-n>', '<Nop>', { silent = true })
            vim.keymap.set('c', '<C-p>', '<Nop>', { silent = true })

            cmp.setup.cmdline({ "/", "?" }, {
              mapping = cmp.mapping.preset.cmdline({
                ['<C-n>'] = {
                  c = function(fallback)
                    if cmp.visible() then
                      cmp.select_next_item()
                    else
                      cmp.complete()
                    end
                  end,
                },
                ['<C-p>'] = {
                  c = function(fallback)
                    if cmp.visible() then
                      cmp.select_prev_item()
                    else
                      cmp.complete()
                    end
                  end,
                },
                ['<PageDown>'] = { c = cmp.mapping.select_next_item({ count = 10 }) },
                ['<PageUp>'] = { c = cmp.mapping.select_prev_item({ count = 10 }) },
                ['<C-Space>'] = { c = cmp.mapping.complete() },
                ['<C-e>'] = { c = cmp.mapping.abort() },
                ['<CR>'] = { c = cmp.mapping.confirm({ select = false }) },
              }),
              sources = {
                { name = "buffer" }
              }
            })

            cmp.setup.cmdline(":", {
              mapping = cmp.mapping.preset.cmdline({
                ['<C-n>'] = {
                  c = function(fallback)
                    if cmp.visible() then
                      cmp.select_next_item()
                    else
                      cmp.complete()
                    end
                  end,
                },
                ['<C-p>'] = {
                  c = function(fallback)
                    if cmp.visible() then
                      cmp.select_prev_item()
                    else
                      cmp.complete()
                    end
                  end,
                },
                ['<PageDown>'] = { c = cmp.mapping.select_next_item({ count = 10 }) },
                ['<PageUp>'] = { c = cmp.mapping.select_prev_item({ count = 10 }) },
                ['<C-Space>'] = { c = cmp.mapping.complete() },
                ['<C-e>'] = { c = cmp.mapping.abort() },
                ['<CR>'] = { c = cmp.mapping.confirm({ select = false }) },
              }),
              sources = cmp.config.sources({
                { name = "path" }
              }, {
                { name = "cmdline" }
              })
            })
          end
          ${if !(self.settings.enableCmdline) then "]]" else ""}
        '';
      };
    };
}
