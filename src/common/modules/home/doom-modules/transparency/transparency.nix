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
      home.file.".config/doom/config/60-transparency.el".text = ''
        (defun my/set-transparency (alpha-bg)
          "Set background transparency to ALPHA-BG (0-100)."
          (interactive "nAlpha-background value (0-100): ")
          (set-frame-parameter nil 'alpha-background alpha-bg))

        (defun set-terminal-transparency (&optional frame)
          "Remove background colors in terminal to enable transparency, but keep tab bar solid black."
          (unless (display-graphic-p frame)
            (let ((frame (or frame (selected-frame))))
              ;; Make main background transparent
              (set-face-background 'default "unspecified-bg" frame)
              
              ;; Force tab systems to be solid black (not transparent)
              (when (facep 'centaur-tabs-default)
                (set-face-background 'centaur-tabs-default "#000000" frame))
              (when (facep 'header-line)
                (set-face-background 'header-line "#000000" frame))
              (when (facep 'tab-bar)
                (set-face-background 'tab-bar "#000000" frame))
              (when (facep 'tab-line)
                (set-face-background 'tab-line "#000000" frame)))))

        (add-hook 'window-setup-hook #'set-terminal-transparency)
        (add-hook 'after-make-frame-functions #'set-terminal-transparency)

        ;; Set transparency for GUI mode
        (when (display-graphic-p)
          (if (>= emacs-major-version 29)
              (progn
                (set-frame-parameter nil 'alpha-background 85)
                (add-to-list 'default-frame-alist '(alpha-background . 85)))
            (progn
              (set-frame-parameter nil 'alpha '(85 . 80))
              (add-to-list 'default-frame-alist '(alpha . (85 . 80))))))
      '';
    };
}
