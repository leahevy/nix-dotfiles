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
      extraPatterns = [
        {
          pattern = "*.log";
          filesize = 0;
        }
      ];
      featuresDisabled = [
        "lsp"
        "treesitter"
      ];
    };
    fastmacro = {
      featuresDisabled = [
        "lualine"
      ];
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = [
          pkgs.vimPlugins.faster-nvim
        ];

        extraConfigLua = ''
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
                    ) self.settings.bigfile.extraPatterns
                  } },
                  features_disabled = { ${
                    lib.concatMapStringsSep ", " (feature: "\"${feature}\"") (
                      self.settings.bigfile.featuresDisabled ++ [ "is_bigfile" ]
                    )
                  } },
                },
                fastmacro = {
                  on = true,
                  features_disabled = { ${
                    lib.concatMapStringsSep ", " (feature: "\"${feature}\"") (
                      self.settings.fastmacro.featuresDisabled ++ [ "is_bigfile" ]
                    )
                  } },
                },
              },
              features = {
                lsp = {
                  on = true,
                  defer = false,
                },
                treesitter = {
                  on = true,
                  defer = false,
                },
                lualine = {
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
              end
            '';
          }
        ];
      };
    };
}
