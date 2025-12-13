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

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enableHighlighting = true;
    enableIndentation = true;
    enableFolding = true;
    grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
      asm
      awk
      bash
      bibtex
      c
      c_sharp
      caddy
      cairo
      cpp
      css
      csv
      cmake
      desktop
      devicetree
      diff
      dockerfile
      editorconfig
      fish
      git_config
      git_rebase
      gitattributes
      gitcommit
      gitignore
      go
      glsl
      gnuplot
      gpg
      graphql
      groovy
      html
      haskell
      haskell_persistent
      http
      jq
      javascript
      jinja
      jinja_inline
      json
      jsonc
      kdl
      idris
      lua
      make
      matlab
      muttrc
      markdown
      markdown_inline
      mermaid
      nasm
      nix
      nginx
      nu
      objc
      passwd
      pem
      powershell
      printf
      properties
      proto
      python
      pymanifest
      r
      readline
      regex
      requirements
      rust
      ruby
      ql
      scss
      sql
      strace
      swift
      ssh_config
      solidity
      scala
      tmux
      turtle
      terraform
      toml
      typescript
      typespec
      vim
      vimdoc
      yaml
      latex
      udev
      xml
      xresources
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

      programs.nixvim.opts =
        lib.mkIf (self.settings.enableFolding && !(self.isModuleEnabled "nvim-modules.nvim-ufo"))
          {
            foldmethod = "expr";
            foldexpr = "nvim_treesitter#foldexpr()";
            foldenable = false;
          };
    };
}
