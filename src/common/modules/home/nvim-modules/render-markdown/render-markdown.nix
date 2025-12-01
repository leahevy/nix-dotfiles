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
  name = "render-markdown";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enabled = true;
    debounce = 100;
    maxFileSize = 10.0;
    preset = "none";
    antiConceal = true;
  };

  submodules = {
    common = {
      nvim-modules = {
        treesitter = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.extraConfigLua = ''
        _G.nx_modules = _G.nx_modules or {}
        _G.nx_modules["85-render-markdown"] = function()
          vim.treesitter.language.register('markdown', 'vimwiki')
        end
      '';

      programs.nixvim.plugins.render-markdown = {
        enable = true;

        settings = {
          enabled = self.settings.enabled;
          debounce = self.settings.debounce;
          max_file_size = self.settings.maxFileSize;
          preset = self.settings.preset;

          win_options = {
            conceallevel = {
              default = 0;
              rendered = 2;
            };
            concealcursor = {
              default = "";
              rendered = "nc";
            };
          };

          file_types = [
            "markdown"
          ]
          ++ (lib.optional (self.isModuleEnabled "nvim-modules.vimwiki") "vimwiki");

          injections = {
            gitcommit = {
              enabled = true;
              query = ''
                ((message) @injection.content
                 (#set! injection.combined)
                 (#set! injection.include-children)
                 (#set! injection.language "markdown"))
              '';
            };
          };
        }
        // lib.optionalAttrs self.settings.antiConceal {
          anti_conceal = {
            enabled = true;
          };
        };
      };

      programs.nixvim.autoCmd = [
        {
          event = [ "FileType" ];
          pattern = [
            "markdown"
          ]
          ++ (lib.optional (self.isModuleEnabled "nvim-modules.vimwiki") "vimwiki");
          callback = {
            __raw = ''
              function()
                vim.opt_local.tabstop = 4
                vim.opt_local.shiftwidth = 4
              end
            '';
          };
        }
      ];
    };
}
