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
  name = "claude";

  unfree = [ "claude-code" ];

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = with pkgs-unstable; [
          claude-code
        ];

        file.".config/doom/config/80-claude.el".text =
          if (self.isModuleEnabled "emacs.doom") then
            ''
              (use-package claude-code-ide
                :bind ("C-c '" . claude-code-ide-menu)
                :config
                (claude-code-ide-emacs-tools-setup)
                (setq claude-code-ide-terminal-backend 'eat))
            ''
          else
            "";

        file.".config/doom/packages/80-claude.el".text =
          if (self.isModuleEnabled "emacs.doom") then
            ''
              (package! claude-code-ide
                :recipe (:host github :repo "manzaltu/claude-code-ide.el" :files ("*.el")))
            ''
          else
            "";

        persistence."${self.persist}" = {
          directories = [
            ".claude"
          ];
          files = [
            ".claude.json"
          ];
        };
      };
    };
}
