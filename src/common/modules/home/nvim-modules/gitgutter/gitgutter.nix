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

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.gitgutter = {
          enable = true;
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>hp";
            action = ":GitGutterPreviewHunk<CR>";
            options = {
              silent = true;
              desc = "Preview hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>hs";
            action = ":GitGutterStageHunk<CR>";
            options = {
              silent = true;
              desc = "Stage hunk";
            };
          }
          {
            mode = "n";
            key = "<leader>hu";
            action = ":GitGutterUndoHunk<CR>";
            options = {
              silent = true;
              desc = "Undo hunk";
            };
          }
        ];
      };
    };
}
