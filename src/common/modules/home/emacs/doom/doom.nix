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
  name = "doom";

  submodules = {
    common = {
      doom-modules = {
        cache-dir = true;
        coding-setup = true;
        copilot = true;
        doom-dashboard = true;
        eat = true;
        shell = true;
        theme = true;
        transparency = true;
        vim = true;
        nix-doom-logo = true;
      };
    };
  };

  defaults = {
    input = [
      # "bidi"
      # "chinese"
      # "japanese"
      # "layout"
    ];

    completion = [
      {
        name = "company";
        flags = [ "+childframe" ];
      }
      {
        name = "corfu";
        flags = [ "+orderless" ];
      }
      "helm"
      # "ido"
      # "ivy"
      # "vertico"
    ];

    ui = [
      # "deft"
      "doom"
      "doom-dashboard"
      # "doom-quit"
      {
        name = "emoji";
        flags = [ "+unicode" ];
      }
      "hl-todo"
      "indent-guides"
      "ligatures"
      "minimap"
      "modeline"
      "nav-flash"
      "neotree"
      "ophints"
      {
        name = "popup";
        flags = [ "+defaults" ];
      }
      "smooth-scroll"
      # "tabs"
      "treemacs"
      "unicode"
      {
        name = "vc-gutter";
        flags = [ "+pretty" ];
      }
      "vi-tilde-fringe"
      # "window-select"
      "workspaces"
      # "zen"
    ];

    editor = [
      {
        name = "evil";
        flags = [ "+everywhere" ];
      }
      "file-templates"
      "fold"
      {
        name = "format";
        flags = [ "+onsave" ];
      }
      # "god"
      # "lispy"
      # "multiple-cursors"
      # "objed"
      # "parinfer"
      # "rotate-text"
      "snippets"
      "word-wrap"
    ];

    emacs = [
      "dired"
      "electric"
      # "eww"
      "ibuffer"
      "undo"
      "vc"
    ];

    term = [
      # "eshell"
      # "shell"
      # "term"
      "vterm"
    ];

    checkers = [
      "syntax"
      {
        name = "spell";
        flags = [ "+flyspell" ];
      }
      # "grammar"
    ];

    tools = [
      "ansible"
      # "biblio"
      # "collab"
      # "debugger"
      "direnv"
      "docker"
      "editorconfig"
      # "ein"
      {
        name = "eval";
        flags = [ "+overlay" ];
      }
      "lookup"
      "llm"
      "lsp"
      "magit"
      "make"
      # "pass"
      # "pdf"
      "terraform"
      "tmux"
      "tree-sitter"
      # "upload"
    ];

    os = [
      {
        name = "macos";
        condition = "(featurep :system 'macos)";
      }
      "tty"
    ];

    lang = [
      # "agda"
      # "beancount"
      {
        name = "cc";
        flags = [ "+lsp" ];
      }
      "clojure"
      "common-lisp"
      # "coq"
      # "crystal"
      # "csharp"
      "data"
      # "dart"
      # "dhall"
      "elixir"
      # "elm"
      "emacs-lisp"
      # "erlang"
      # "ess"
      # "factor"
      # "faust"
      # "fortran"
      # "fsharp"
      # "fstar"
      # "gdscript"
      {
        name = "go";
        flags = [ "+lsp" ];
      }
      {
        name = "graphql";
        flags = [ "+lsp" ];
      }
      {
        name = "haskell";
        flags = [ "+lsp" ];
      }
      # "hy"
      "idris"
      "json"
      # "janet"
      {
        name = "java";
        flags = [ "+lsp" ];
      }
      {
        name = "javascript";
        flags = [ "+lsp" ];
      }
      # "julia"
      "kotlin"
      "latex"
      # "lean"
      # "ledger"
      "lua"
      "markdown"
      # "nim"
      "nix"
      # "ocaml"
      "org"
      "php"
      "plantuml"
      "graphviz"
      # "purescript"
      {
        name = "python";
        flags = [
          "+lsp"
          "+conda"
        ];
      }
      # "qt"
      # "racket"
      # "raku"
      "rest"
      # "rst"
      {
        name = "ruby";
        flags = [ "+rails" ];
      }
      {
        name = "rust";
        flags = [ "+lsp" ];
      }
      "scala"
      {
        name = "scheme";
        flags = [ "+guile" ];
      }
      "sh"
      # "sml"
      # "solidity"
      "swift"
      # "terra"
      # "web"
      "yaml"
      # "zig"
    ];

    email = [
      # "mu4e"
      # "notmuch"
      # "wanderlust"
    ];

    app = [
      # "calendar"
      # "emms"
      # "everywhere"
      # "irc"
      # "rss"
    ];

    config = [
      # "literate"
      {
        name = "default";
        flags = [
          "+bindings"
          "+smartparens"
        ];
      }
    ];
  };

  submodules = {
    common = {
      emacs = {
        emacs = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      generateModuleEntry =
        module:
        if builtins.isString module then
          module
        else if module ? condition then
          "(:if ${module.condition} ${module.name})"
        else if module ? flags then
          "(${module.name} ${lib.concatStringsSep " " module.flags})"
        else
          module.name;

      generateCategorySection =
        category: modules:
        let
          enabledModules = builtins.filter (m: m != null) modules;
          moduleEntries = map generateModuleEntry enabledModules;
        in
        if enabledModules == [ ] then
          ""
        else
          "       :${category}\n"
          + (lib.concatMapStringsSep "\n" (entry: "       ${entry}") moduleEntries)
          + "\n";

      generateInitEl =
        modules:
        let
          categoryOrder = [
            "input"
            "completion"
            "ui"
            "editor"
            "emacs"
            "term"
            "checkers"
            "tools"
            "os"
            "lang"
            "email"
            "app"
            "config"
          ];

          orderedSections = map (
            category: if modules ? ${category} then generateCategorySection category modules.${category} else ""
          ) categoryOrder;

          nonEmptySections = builtins.filter (s: s != "") orderedSections;
        in
        "(doom!" + (lib.concatStringsSep "\n" nonEmptySections) + ")";

      doomInstallScript = pkgs.writeShellScriptBin "doom-install" ''
        DOOM_CONFIG_DIR="$HOME/.config/emacs"

        if [[ -d "$DOOM_CONFIG_DIR" && "$(ls -A "$DOOM_CONFIG_DIR")" ]]; then
          echo "Doom Emacs directory exists and is not empty"
          read -p "Clean and reinstall? [y/N]: " response
          if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Cleaning existing installation..."
            rm -rf "$DOOM_CONFIG_DIR"/* "$DOOM_CONFIG_DIR"/.* 2>/dev/null || true
          else
            echo "Aborted"
            exit 0
          fi
        fi

        echo "Installing Doom Emacs"
        if git clone --depth 1 https://github.com/doomemacs/doomemacs.git "$DOOM_CONFIG_DIR"; then
          echo "Running doom install..."
          if "$DOOM_CONFIG_DIR/bin/doom" install --force; then
            echo "Doom Emacs installed successfully"
          else
            echo "Doom install failed, cleaning up"
            rm -rf "$DOOM_CONFIG_DIR"/* "$DOOM_CONFIG_DIR"/.* 2>/dev/null || true
            exit 1
          fi
        else
          echo "Failed to clone Doom Emacs repository"
          exit 1
        fi
      '';
    in
    {
      home.packages = with pkgs; [
        git
        gnumake
        ripgrep
        findutils
        coreutils
        doomInstallScript
      ];

      home.file = {
        ".config/doom/init.el".text = generateInitEl self.settings;
        ".config/doom/config.el".source = self.file "doom/config.el";
        ".config/doom/packages.el".source = self.file "doom/packages.el";
        ".config/doom/custom.el".source = self.file "doom/custom.el";
        ".config/doom/config/00-default.el".source = self.file "doom/config/00-default.el";
        ".config/doom/packages/00-default.el".source = self.file "doom/packages/00-default.el";
        ".config/doom/custom/00-default.el".source = self.file "doom/custom/00-default.el";
      };

      home.sessionPath = [ "$HOME/.config/emacs/bin" ];

      home.shellAliases = {
        doom = "$HOME/.config/emacs/bin/doom";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/doom"
        ];
      };
    };
}
