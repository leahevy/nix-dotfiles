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
  name = "copilot";

  group = "doom-modules";
  input = "common";
  namespace = "home";

  unfree = [ "copilot-language-server" ];

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
          (add-to-list 'copilot-indentation-alist '(emacs-lisp-mode 2))

          ;; Fix copilot face colors for dark themes
          (custom-set-faces
           '(copilot-overlay-face ((t (:foreground "#6272a4" :background nil))))
           '(copilot-completion-face ((t (:foreground "#6272a4" :background nil))))))
      '';

      home.file.".config/doom/packages/80-copilot.el".text = ''
        (package! copilot
          :recipe (:host github :repo "copilot-emacs/copilot.el" :files ("*.el")))
      '';
    };
}
