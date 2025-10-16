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
  name = "theme";

  group = "doom-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/doom/themes/doom-coastal-theme.el".source = ./doom-coastal-theme.el;

      home.file.".config/doom/config/10-load-themes.el".text = ''
        (add-to-list 'custom-theme-load-path (expand-file-name "themes" doom-private-dir))

        ;; Fix line numbers and comments after theme loads
        (add-hook 'doom-load-theme-hook
          (lambda ()
            ;; Line numbers: darker green for normal, bright green for current
            (set-face-attribute 'line-number nil :foreground "#687d68" :background nil)
            (set-face-attribute 'line-number-current-line nil :foreground "#29a329" :weight 'bold :background nil)
            
            ;; Make comments visible with brighter gray-green
            (set-face-attribute 'font-lock-comment-face nil :foreground "#7a9a7a" :background nil)
            (set-face-attribute 'font-lock-comment-delimiter-face nil :foreground "#7a9a7a" :background nil)
            
            ;; Splash screen logo: light blue/cyan
            (set-face-attribute 'doom-dashboard-menu-title nil :foreground "#1999b3" :weight 'bold :background nil)))
      '';

      home.file.".config/doom/config/20-doom-coastal-theme.el".text = ''
        (setq doom-theme 'doom-coastal)
      '';
    };
}
