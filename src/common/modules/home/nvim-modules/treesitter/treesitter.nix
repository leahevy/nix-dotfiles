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
  name = "treesitter";

  defaults = {
    enableHighlighting = true;
    enableIndentation = true;
    enableFolding = true;
    grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      bash
      c
      cpp
      css
      dockerfile
      fish
      git_config
      git_rebase
      gitattributes
      gitcommit
      gitignore
      go
      html
      javascript
      json
      lua
      markdown
      markdown_inline
      nix
      python
      rust
      toml
      typescript
      vim
      vimdoc
      yaml
      latex
    ];
    extraGrammars = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.treesitter = {
        enable = true;

        nixvimInjections = true;

        grammarPackages = self.settings.grammarPackages ++ self.settings.extraGrammars;

        settings = {
          auto_install = false;

          highlight = {
            enable = self.settings.enableHighlighting;
            additional_vim_regex_highlighting = false;
          };

          indent = {
            enable = self.settings.enableIndentation;
          };
        }
        // lib.optionalAttrs self.settings.enableFolding {
          fold = {
            enable = true;
          };
        };
      };

      programs.nixvim.opts = lib.mkIf self.settings.enableFolding {
        foldmethod = "expr";
        foldexpr = "nvim_treesitter#foldexpr()";
        foldenable = false;
      };
    };
}
