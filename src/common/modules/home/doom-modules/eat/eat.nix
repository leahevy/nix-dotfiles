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
      home.file.".config/doom/config/40-eat.el".text = ''
        (use-package! eat
          :config
          (add-hook 'eshell-load-hook #'eat-eshell-mode)
          (setq eat-shell (getenv "SHELL"))
          
          (defun shell-other-window-right-of ()
            "Open a `shell' in a new window."
            (interactive)
            (let ((buf (eat)))
              (switch-to-buffer (other-buffer buf))
              (switch-to-buffer-other-window buf)))

          (defun shell-other-window-below-of ()
            "Open a `shell' in a new window below."
            (interactive)
            (let ((buf (eat)))
              (switch-to-buffer (other-buffer buf))
              (split-window-below)
              (other-window 1)
              (switch-to-buffer buf))))

        (map! :n "SPC j" #'shell-other-window-below-of)
      '';

      home.file.".config/doom/packages/40-eat.el".text = ''
        (package! eat
          :recipe (:host codeberg
               :repo "akib/emacs-eat"
               :files ("*.el" ("term" "term/*.el") "*.texi"
                       "*.ti" ("terminfo/e" "terminfo/e/*")
                       ("terminfo/65" "terminfo/65/*")
                       ("integration" "integration/*")
                       (:exclude ".dir-locals.el" "*-tests.el"))))
      '';
    };
}
