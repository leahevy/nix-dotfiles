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
      home.file.".config/doom/config/10-shell.el".text = ''
        (setq shell-file-name (executable-find "bash"))

        ;; Fix PATH and exec-path to include Nix profile
        (setenv "PATH" (concat (getenv "HOME") "/.nix-profile/bin:" (getenv "PATH")))
        (setq exec-path (append (list (concat (getenv "HOME") "/.nix-profile/bin")) exec-path))

        (setq-default vterm-shell (getenv "SHELL"))
        (setq-default explicit-shell-file-name (getenv "SHELL"))
      '';
    };
}
