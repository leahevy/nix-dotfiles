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
  name = "grug-far";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.grug-far = {
          enable = true;
          settings = {
            engine = "ripgrep";
            debounceMs = 500;
            maxSearchMatches = 2000;
            maxWorkers = 4;
            minSearchChars = 2;
            normalModeSearch = false;
            transient = false;
            folding = {
              enabled = true;
              foldlevel = 1;
            };
            resultLocation = {
              showNumberLabel = true;
            };
            highlightMatches = true;
            windowCreationCommand = "botright split";
            historyMaxSize = 20;
            icons = {
              enabled = true;
            };
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>sg";
            action = "<cmd>GrugFar<CR>";
            options = {
              desc = "Project-wide search & replace";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>sg";
            desc = "Project-wide search & replace";
            icon = "🔍";
          }
        ];
      };
    };
}
