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

  group = "nvim-modules";
  input = "common";
  namespace = "home";

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
            key = "<Tab>";
            action = "empty(copilot#GetDisplayedSuggestion()) ? '\\<Tab>' : copilot#Accept()";
            options = {
              desc = "Accept Copilot suggestion";
              silent = true;
              expr = true;
              replace_keycodes = false;
            };
          }
          {
            mode = "i";
            key = "<M-Tab>";
            action = "<cmd>lua vim.api.nvim_feedkeys('\t', 'n', false)<CR>";
            options = {
              desc = "Insert tab (fallback)";
              silent = true;
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

        autoCmd = lib.mkIf (self.isModuleEnabled "nvim-modules.vimwiki") [
          {
            event = [ "BufEnter" ];
            pattern = [ "*.md" ];
            callback.__raw = ''
              function()
                if vim.bo.filetype == "vimwiki" then
                  vim.defer_fn(function()
                    vim.keymap.set('i', '<Tab>',
                      "empty(copilot#GetDisplayedSuggestion()) ? '\\<Tab>' : copilot#Accept()",
                      { buffer = 0, desc = "Accept Copilot suggestion", silent = true, expr = true, replace_keycodes = false }
                    )
                  end, 10)
                end
              end
            '';
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<Tab>";
            desc = "Accept Copilot suggestion or tab";
            icon = "✈️";
          }
          {
            __unkeyed-1 = "<M-Tab>";
            desc = "Insert tab (fallback)";
            icon = "->";
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
