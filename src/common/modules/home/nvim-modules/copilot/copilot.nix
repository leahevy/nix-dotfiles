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

        globals = {
          copilot_no_tab_map = true;
          copilot_assume_mapped = true;
        };

        keymaps = [
          {
            mode = "i";
            key = "<C-]>";
            action = "copilot#Accept('\\<CR>')";
            options = {
              desc = "Accept Copilot suggestion";
              silent = true;
              expr = true;
              replace_keycodes = false;
            };
          }
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

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<C-]>";
            desc = "Accept Copilot suggestion";
            icon = "✈️";
          }
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
