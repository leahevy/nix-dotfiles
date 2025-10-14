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
  name = "auto-session";

  defaults = {
    autoSave = true;
    autoRestore = true;
    autoCreate = true;
    suppressedDirs = [
      "~/"
      "/tmp"
    ];
    cwdChangeHandling = false;
    logLevel = "error";
    sessionLensLoadOnSetup = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        opts = {
          sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions";
        };

        plugins.auto-session = {
          enable = true;

          settings = {
            enabled = true;
            auto_save = self.settings.autoSave;
            auto_restore = self.settings.autoRestore;
            auto_create = self.settings.autoCreate;
            suppressed_dirs = self.settings.suppressedDirs;
            use_git_branch = false;
            cwd_change_handling = self.settings.cwdChangeHandling;
            log_level = self.settings.logLevel;

            bypass_save_filetypes = [
              "dashboard"
              "alpha"
              "netrw"
              "toggleterm"
            ];

            pre_save_cmds = lib.mkIf (self.isModuleEnabled "nvim-modules.nvim-tree") [
              "tabdo NvimTreeClose"
            ];

            post_restore_cmds = [ ];

            session_lens = {
              load_on_setup = self.settings.sessionLensLoadOnSetup;
              previewer = false;
              picker_opts = {
                layout_strategy = "horizontal";
                layout_config = {
                  width = 0.8;
                  height = 0.8;
                };
              };
            };
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>So";
            action = "<cmd>Telescope session-lens<CR>";
            options = {
              silent = true;
              desc = "Open session picker";
            };
          }
          {
            mode = "n";
            key = "<leader>Sd";
            action = "<cmd>Autosession deletePicker<CR>";
            options = {
              silent = true;
              desc = "Delete session picker";
            };
          }
          {
            mode = "n";
            key = "<leader>Sc";
            action = ":Autosession save ";
            options = {
              silent = false;
              desc = "Save named session";
            };
          }
          {
            mode = "n";
            key = "<leader>Ss";
            action = "<cmd>Autosession save<CR>";
            options = {
              silent = true;
              desc = "Save current session";
            };
          }
          {
            mode = "n";
            key = "<leader>Sr";
            action = "<cmd>lua require('auto-session').RestoreSession(vim.fn.getcwd())<CR>";
            options = {
              silent = true;
              desc = "Restore session for current directory";
            };
          }
        ];
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>S";
              group = "session";
              icon = "󰆓";
            }
            {
              __unkeyed-1 = "<leader>So";
              desc = "Open session picker";
              icon = "󰋚";
            }
            {
              __unkeyed-1 = "<leader>Sd";
              desc = "Delete session";
              icon = "󰆴";
            }
            {
              __unkeyed-1 = "<leader>Sc";
              desc = "Save named session";
              icon = "󰆓";
            }
            {
              __unkeyed-1 = "<leader>Ss";
              desc = "Save current session";
              icon = "󰆓";
            }
            {
              __unkeyed-1 = "<leader>Sr";
              desc = "Restore session for cwd";
              icon = "󰦛";
            }
          ];
    };
}
