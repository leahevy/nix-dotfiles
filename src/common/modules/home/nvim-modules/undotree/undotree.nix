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
  name = "undotree";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.undotree = {
          enable = true;
        };

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>U";
            desc = "Toggle UndoTree";
            icon = "⎌";
          }
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>U";
            action = "<cmd>UndotreeToggle<CR>";
            options = {
              desc = "Toggle UndoTree";
              silent = true;
            };
          }
        ];
      };
    };
}
