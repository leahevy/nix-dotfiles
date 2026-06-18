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

  settings = {
    enableHighlighting = true;
    enableIndentation = true;
    enableFolding = true;
    grammarPackages = [
      "asm"
      "awk"
      "bash"
      "bibtex"
      "c"
      "c_sharp"
      "caddy"
      "cairo"
      "cpp"
      "css"
      "csv"
      "cmake"
      "desktop"
      "devicetree"
      "diff"
      "dockerfile"
      "editorconfig"
      "fish"
      "git_config"
      "git_rebase"
      "gitattributes"
      "gitcommit"
      "gitignore"
      "go"
      "glsl"
      "gnuplot"
      "gpg"
      "graphql"
      "groovy"
      "html"
      "haskell"
      "haskell_persistent"
      "http"
      "jq"
      "javascript"
      "jinja"
      "jinja_inline"
      "json"
      "kdl"
      "idris"
      "lua"
      "make"
      "matlab"
      "muttrc"
      "markdown"
      "markdown_inline"
      "mermaid"
      "nasm"
      "nix"
      "nginx"
      "nu"
      "objc"
      "passwd"
      "pem"
      "powershell"
      "printf"
      "properties"
      "proto"
      "python"
      "pymanifest"
      "r"
      "readline"
      "regex"
      "requirements"
      "rust"
      "ruby"
      "ql"
      "scss"
      "sql"
      "strace"
      "swift"
      "ssh_config"
      "solidity"
      "scala"
      "tmux"
      "turtle"
      "terraform"
      "toml"
      "typescript"
      "typespec"
      "vim"
      "vimdoc"
      "yaml"
      "latex"
      "udev"
      "xml"
      "xresources"
    ];
    extraGrammars = [ ];
  };

  module = {
    home =
      config:
      let
        treesitterPkg = config.programs.nixvim.plugins.treesitter.package;
        resolvedGrammars = map (name: treesitterPkg.builtGrammars.${name}) self.settings.grammarPackages;
      in
      {
        programs.nixvim.plugins.treesitter = {
          enable = true;

          nixvimInjections = true;

          grammarPackages = resolvedGrammars ++ self.settings.extraGrammars;

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
  };
}
