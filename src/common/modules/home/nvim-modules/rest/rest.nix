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
  name = "rest";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.rest = {
          enable = true;
          enableHttpFiletypeAssociation = true;
          enableTelescope = true;
        };

        plugins.treesitter.grammarPackages = lib.mkIf (self.isModuleEnabled "nvim-modules.treesitter") [
          pkgs.vimPlugins.nvim-treesitter.builtGrammars.http
        ];

        keymaps = [
          {
            mode = "n";
            key = "<localleader>rr";
            action = "<cmd>Rest run<CR>";
            options = {
              silent = true;
              desc = "Run request under cursor";
            };
          }
          {
            mode = "n";
            key = "<localleader>re";
            action = "<cmd>Telescope rest select_env<CR>";
            options = {
              silent = true;
              desc = "Select environment";
            };
          }
          {
            mode = "n";
            key = "<localleader>rs";
            action = "<cmd>Rest env show<CR>";
            options = {
              silent = true;
              desc = "Show current environment";
            };
          }
          {
            mode = "n";
            key = "<localleader>rc";
            action = "<cmd>Rest cookies<CR>";
            options = {
              silent = true;
              desc = "Edit cookies";
            };
          }
          {
            mode = "n";
            key = "<localleader>rL";
            action = "<cmd>split | Rest logs<CR>";
            options = {
              silent = true;
              desc = "Show logs in split";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<localleader>r";
            group = "REST API";
            icon = "🌐";
          }
          {
            __unkeyed-1 = "<localleader>rr";
            desc = "Run request under cursor";
            icon = "▶️";
          }
          {
            __unkeyed-1 = "<localleader>re";
            desc = "Select environment";
            icon = "🌍";
          }
          {
            __unkeyed-1 = "<localleader>rs";
            desc = "Show current environment";
            icon = "📋";
          }
          {
            __unkeyed-1 = "<localleader>rc";
            desc = "Edit cookies";
            icon = "🍪";
          }
          {
            __unkeyed-1 = "<localleader>rL";
            desc = "Show logs in split";
            icon = "📄";
          }
        ];
      };

      home.packages = with pkgs; [
        curl
      ];
    };
}
