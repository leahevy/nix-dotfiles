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
  name = "dashboard";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.dashboard = {
          enable = true;
          settings = {
            theme = "hyper";
            disable_move = true;
            change_to_vcs_root = true;
            shortcut_type = "number";
            config = {
              header = [
                "                                "
                "                                "
                "       ◢██◣   ◥███◣  ◢██◣       "
                "       ◥███◣   ◥███◣◢███◤       "
                "        ◥███◣   ◥██████◤        "
                "    ◢█████████████████◤   ◢◣    "
                "   ◢██████████████████◣  ◢██◣   "
                "        ◢███◤      ◥███◣◢███◤   "
                "       ◢███◤        ◥██████◤    "
                "◢█████████◤          ◥█████████◣"
                "◥█████████◣          ◢█████████◤"
                "    ◢██████◣        ◢███◤       "
                "   ◢███◤◥███◣      ◢███◤        "
                "   ◥██◤  ◥██████████████████◤   "
                "    ◥◤   ◢█████████████████◤    "
                "        ◢██████◣   ◥███◣        "
                "       ◢███◤◥███◣   ◥███◣       "
                "       ◥██◤  ◥███◣   ◥██◤       "
                "                                "
                "                                "
                "                                "
              ];
              shortcut = [
                {
                  desc = " Find File";
                  group = "@property";
                  action = "Telescope find_files";
                  key = "f";
                }
                {
                  desc = " New File";
                  group = "Number";
                  action = "enew";
                  key = "n";
                }
                {
                  desc = " Recent Files";
                  group = "Label";
                  action = "Telescope oldfiles";
                  key = "r";
                }
                {
                  desc = " Find Text";
                  group = "DiagnosticHint";
                  action = "Telescope live_grep";
                  key = "g";
                }
                {
                  desc = " Core";
                  group = "DiagnosticInfo";
                  action = "lua vim.cmd('cd ' .. vim.env.NXCORE_DIR) vim.cmd('Telescope find_files')";
                  key = "c";
                }
                {
                  desc = " Config";
                  group = "DiagnosticWarn";
                  action = "lua vim.cmd('cd ' .. vim.env.NXCONFIG_DIR) vim.cmd('Telescope find_files')";
                  key = "C";
                }
                {
                  desc = " Quit";
                  group = "DiagnosticError";
                  action = "quit";
                  key = "q";
                }
              ];
              packages = {
                enable = false;
              };
              project = {
                enable = true;
                limit = 8;
                action = "Telescope find_files cwd=";
              };
              mru = {
                limit = 10;
              };
              footer = [ "" ];
            };
          };

        };

        keymaps = [
          {
            key = "<leader>d";
            action = ":Dashboard<CR>";
            options.silent = true;
          }
        ];
      };

      home.file.".config/nvim-init/60-dashboard-rainbow.lua".text = ''
        vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#e5c075", bold = true })

        vim.api.nvim_set_hl(0, "DashboardProjectTitle", { fg = "#61afef", bold = true })
        vim.api.nvim_set_hl(0, "DashboardProjectTitleIcon", { fg = "#e06c75" })
        vim.api.nvim_set_hl(0, "DashboardProjectIcon", { fg = "#61afef" })
        vim.api.nvim_set_hl(0, "DashboardMruTitle", { fg = "#98c379", bold = true })
        vim.api.nvim_set_hl(0, "DashboardMruIcon", { fg = "#e5c07b" })
        vim.api.nvim_set_hl(0, "DashboardFiles", { fg = "#abb2bf" })
        vim.api.nvim_set_hl(0, "DashboardShortCutIcon", { fg = "#c678dd" })
      '';
    };
}
