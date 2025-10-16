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
  name = "gitgutter";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.gitgutter = {
          enable = true;
          settings = {
            map_keys = false;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>gp";
            action = ":GitGutterPreviewHunk<CR>";
            options = {
              silent = true;
              desc = "Preview hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gs";
            action = ":GitGutterStageHunk<CR>";
            options = {
              silent = true;
              desc = "Stage hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>gu";
            action = ":GitGutterUndoHunk<CR>";
            options = {
              silent = true;
              desc = "Undo hunk";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>g";
            group = "git";
            icon = "⇡";
          }
          {
            __unkeyed-1 = "<leader>gp";
            desc = "Preview hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "<leader>gs";
            desc = "Stage hunk";
            icon = "󰐕";
          }
          {
            __unkeyed-1 = "<leader>gu";
            desc = "Undo hunk";
            icon = "󰐕";
          }
        ];
      };
    };
}
