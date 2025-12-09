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
  name = "faster";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    bigfile = {
      filesize = 5;
      additionalExtraPatterns = [ ];
      additionalFeaturesDisabled = [ ];
    };
    fastmacro = {
      additionalFeaturesDisabled = [ ];
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = [
          pkgs.vimPlugins.faster-nvim
        ];

        extraConfigLua =
          let
            bigFileFeaturesDisabled =
              self.settings.bigfile.additionalFeaturesDisabled
              ++ [
                "is_bigfile"
                "vimopts"
              ]
              ++ lib.optionals (self.isModuleEnabled "nvim-modules.lsp") [ "lsp" ]
              ++ lib.optionals (self.isModuleEnabled "nvim-modules.treesitter") [ "treesitter" ];

            macroFeaturesDisabled =
              self.settings.fastmacro.additionalFeaturesDisabled
              ++ [ "is_macro_execution" ]
              ++ lib.optionals (self.isModuleEnabled "nvim-modules.lualine") [ "lualine" ];

            bigFileExtraPatterns = self.settings.bigfile.additionalExtraPatterns ++ [
              {
                pattern = "*.log";
                filesize = 0;
              }
            ];
          in
          ''
            _G.nx_modules = _G.nx_modules or {}
            _G.nx_modules["60-faster"] = function()
              require('faster').setup({
                behaviours = {
                  bigfile = {
                    on = true,
                    filesize = ${toString self.settings.bigfile.filesize},
                    pattern = "*",
                    extra_patterns = { ${
                      lib.concatMapStringsSep ", " (
                        pattern:
                        if pattern ? filesize then
                          "{ filesize = ${toString pattern.filesize}, pattern = \"${pattern.pattern}\" }"
                        else
                          "{ pattern = \"${pattern.pattern}\" }"
                      ) bigFileExtraPatterns
                    } },
                    features_disabled = { ${
                      lib.concatMapStringsSep ", " (feature: "\"${feature}\"") (bigFileFeaturesDisabled)
                    } },
                  },
                  fastmacro = {
                    on = true,
                    features_disabled = { ${
                      lib.concatMapStringsSep ", " (feature: "\"${feature}\"") (macroFeaturesDisabled)
                    } },
                  },
                },
                features = {
                  filetype = {
                    on = true,
                    defer = true,
                  },
                  illuminate = {
                    on = true,
                    defer = false,
                  },
                  indent_blankline = {
                    on = true,
                    defer = false,
                  },
                  lsp = {
                    on = true,
                    defer = false,
                  },
                  lualine = {
                    on = true,
                    defer = false,
                  },
                  matchparen = {
                    on = true,
                    defer = false,
                  },
                  syntax = {
                    on = true,
                    defer = true,
                  },
                  treesitter = {
                    on = true,
                    defer = false,
                  },
                  vimopts = {
                    on = true,
                    defer = false,
                  },
                  mini_clue = {
                    on = true,
                    defer = false,
                  },
                  is_bigfile = {
                    on = true,
                    defer = false,

                    commands = function()
                      vim.api.nvim_create_user_command('FasterShowBigfileStatus', function()
                        local is_bigfile = vim.b.is_bigfile or false
                        local status = is_bigfile and "Big file detected" or "Normal file"
                        vim.notify(status, vim.log.levels.INFO, {
                          icon = is_bigfile and "⚠️" or "✅",
                          title = "Faster.nvim"
                        })
                      end, {})
                    end,

                    enable = function()
                      vim.b.is_bigfile = false
                    end,

                    disable = function()
                      vim.b.is_bigfile = true
                    end,
                  },
                  is_macro_execution = {
                    on = true,
                    defer = false,

                    commands = function()
                      vim.api.nvim_create_user_command('FasterShowMacroStatus', function()
                        local is_macro = vim.b.is_macro_execution or false
                        local status = is_macro and "Macro execution detected" or "Normal execution"
                        vim.notify(status, vim.log.levels.INFO, {
                          icon = is_macro and "⚠️" or "✅",
                          title = "Faster.nvim"
                        })
                      end, {})
                    end,

                    enable = function()
                      vim.b.is_macro_execution = false
                    end,

                    disable = function()
                      vim.b.is_macro_execution = true
                    end,
                  },
                }
              })
            end
          '';

        autoCmd = [
          {
            event = "BufEnter";
            callback.__raw = ''
              function()
                if vim.b.is_bigfile == nil then
                  vim.b.is_bigfile = false
                end
                if vim.b.is_macro_execution == nil then
                  vim.b.is_macro_execution = false
                end
              end
            '';
          }
        ];
      };
    };
}
