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
            config = {
              header = [
                ""
                ""
                "       ◢██◣   ◥███◣  ◢██◣       "
                "       ◥███◣   ◥███◣◢███◤       "
                "        ◥███◣   ◥██████◤        "
                "    ◢█████████████████◤   ◢◣    "
                "   ◢██████████████████◣  ◢██◣   "
                "        ◢███◤      ◥███◣◢███◤   "
                "       ◢███◤        ◥██████◤    "
                "◢█████████◤          ◥█████████◣"
                "◥█████████◣          ◢█████████◤"
                "    ◢██████◣        ◢███◤      "
                "   ◢███◤◥███◣      ◢███◤       "
                "   ◥██◤  ◥██████████████████◤  "
                "    ◥◤   ◢█████████████████◤   "
                "        ◢██████◣   ◥███◣       "
                "       ◢███◤◥███◣   ◥███◣      "
                "       ◥██◤  ◥███◣   ◥██◤      "
                ""
                ""
                ""
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
                  desc = " Configuration";
                  group = "DiagnosticInfo";
                  action = "lua vim.cmd('edit ' .. vim.env.NXCORE_DIR .. '/src/common/modules/home/nvim/nixvim/nixvim.nix')";
                  key = "c";
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
