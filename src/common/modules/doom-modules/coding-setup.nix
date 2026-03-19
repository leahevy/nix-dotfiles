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
  name = "coding-setup";

  group = "doom-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/doom/config/70-coding-setup.el".text = ''
        (add-hook 'rjsx-mode-hook
                  #'coding-hooks)
        (add-hook 'python-mode-hook
                  #'coding-hooks)

        (defun coding-hooks ()
          (which-function-mode 1)
          (lsp-mode 1)
          (flyspell-prog-mode 1))
      '';
    };
}
