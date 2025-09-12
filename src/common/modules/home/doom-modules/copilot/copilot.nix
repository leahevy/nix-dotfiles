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
  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        copilot-language-server
      ];

      home.file.".config/doom/config/80-copilot.el".text = ''
        (use-package! copilot
          :hook (prog-mode . copilot-mode)
          :bind (:map copilot-completion-map
                      ("<tab>" . 'copilot-accept-completion)
                      ("TAB" . 'copilot-accept-completion)
                      ("C-TAB" . 'copilot-accept-completion-by-word)
                      ("C-<tab>" . 'copilot-accept-completion-by-word)
                      ("C-n" . 'copilot-next-completion)
                      ("C-p" . 'copilot-previous-completion))

          :config
          (add-to-list 'copilot-indentation-alist '(prog-mode 2))
          (add-to-list 'copilot-indentation-alist '(org-mode 2))
          (add-to-list 'copilot-indentation-alist '(text-mode 2))
          (add-to-list 'copilot-indentation-alist '(closure-mode 2))
          (add-to-list 'copilot-indentation-alist '(emacs-lisp-mode 2)))
      '';

      home.file.".config/doom/packages/80-copilot.el".text = ''
        (package! copilot
          :recipe (:host github :repo "copilot-emacs/copilot.el" :files ("*.el")))
      '';
    };
}
