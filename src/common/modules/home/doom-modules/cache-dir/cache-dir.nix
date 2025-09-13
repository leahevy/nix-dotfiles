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
  name = "cache-dir";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/doom/config/10-cache-dir.el".text = ''
        ;; Ensure cache directory exists
        (defvar my-emacs-cache-dir (expand-file-name "~/.local/cache/emacs/")
          "Custom cache directory for Emacs plugins.")

        ;; Create dir if not exists
        (unless (file-directory-p my-emacs-cache-dir)
          (make-directory my-emacs-cache-dir t))

        ;; Move projectile cache to custom cache directory
        (setq projectile-cache-file (expand-file-name "projectile.cache" my-emacs-cache-dir)
              projectile-known-projects-file (expand-file-name "projectile-bookmarks.eld" my-emacs-cache-dir))
      '';
    };
}
