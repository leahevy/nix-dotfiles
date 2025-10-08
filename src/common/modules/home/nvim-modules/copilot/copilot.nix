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

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs-unstable; [
        nodejs
      ];

      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          copilot-vim
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>cq";
            action = ":lua local status = vim.fn.execute('Copilot status'); if string.match(status, 'Ready') then print('Disabling Copilot...'); vim.cmd('Copilot disable') else print('Enabling Copilot...'); vim.cmd('Copilot enable') end<CR>";
            options = {
              desc = "Toggle Copilot";
              silent = false;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.common.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>cq";
            desc = "Toggle Copilot";
            icon = "✈️";
          }
        ];
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/github-copilot"
        ];
      };
    };
}
