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

  group = "dev";
  input = "common";
  namespace = "home";

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

      programs.nixvim = lib.mkIf (self.isModuleEnabled "nvim.nixvim") {
        extraPlugins = [
          (pkgs.vimUtils.buildVimPlugin {
            pname = "claude-code-nvim";
            version = "c9a31e5";
            src = pkgs.fetchFromGitHub {
              owner = "greggh";
              repo = "claude-code.nvim";
              rev = "c9a31e51069977edaad9560473b5d031fcc5d38b";
              hash = "sha256-ZEIPutxhgyaAhq+fJw1lTO781IdjTXbjKy5yKgqSLjM=";
            };
            dependencies = with pkgs.vimPlugins; [ plenary-nvim ];
          })
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.common.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>cc";
            desc = "Toggle Claude Code";
            icon = "🤖";
          }
        ];
      };

      home.file.".config/nvim-init/90-claude-code.lua" = lib.mkIf (self.isModuleEnabled "nvim.nixvim") {
        text = ''
          require('claude-code').setup({
            window = {
              position = "botright",
              split_ratio = 0.4,
            },
          })

          vim.keymap.set('n', '<leader>cc', '<cmd>ClaudeCode<CR>', {
            desc = 'Toggle Claude Code',
            silent = true
          })
        '';
      };
    };
}
