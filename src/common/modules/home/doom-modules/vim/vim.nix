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
  name = "vim";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/doom/config/20-vim.el".text = ''
        ;; Configure evil-escape for jk to exit insert mode
        (use-package! evil-escape
          :config
          (setq evil-escape-key-sequence "jk")
          (setq evil-escape-delay 0.25)
          (evil-escape-mode 1))

        ;; Make 's' key behave like vim (disable evil-snipe, restore substitute)
        (after! evil-snipe
          (evil-snipe-mode -1)
          (evil-snipe-local-mode -1))

        ;; Restore vim-like 's' and 'S' keybindings
        (map! :n "s" #'evil-substitute
              :n "S" #'evil-change-line)

        ;; Add vim-like minibuffer navigation (j/k for history)
        (map! :map minibuffer-local-map
              "M-j" #'next-history-element
              "M-k" #'previous-history-element)

        ;; Show doc with g-h
        (map! :n "g h" #'lsp-ui-doc-show)

        ;; Swap : and ; in normal mode
        (map! :n ";" #'evil-ex
              :n ":" #'evil-repeat-find-char)
      '';
    };
}
