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

  defaults = {
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
      home.file.".config/nvim-init/85-render-markdown.lua".text = ''
        vim.treesitter.language.register('markdown', 'vimwiki')
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
            "vimwiki"
          ];

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
            "vimwiki"
          ];
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
