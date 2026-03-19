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
  name = "doom-dashboard";

  group = "doom-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/doom/config/20-doom-dashboard.el".text = ''
        (defun my/goto-doom-dashboard ()
          "Switch to the Doom dashboard buffer and ensure we're in normal mode."
          (interactive)
          (let ((dashboard-buffer (get-buffer +doom-dashboard-name)))
            (if dashboard-buffer
                (progn
                  (switch-to-buffer dashboard-buffer)
                  (when (bound-and-true-p evil-mode)
                    (evil-normal-state)))
              ;; If dashboard doesn't exist, create a new one
              (+doom-dashboard/open (selected-frame))
              (when (bound-and-true-p evil-mode)
                (evil-normal-state)))))

        (map! :leader
              :desc "Go to Doom dashboard"
              "d" #'my/goto-doom-dashboard)
      '';
    };
}
