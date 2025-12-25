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
  name = "project";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    autoDetectProjects = true;
    maxProjects = 50;
    showHidden = false;
    changeDirGlobally = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.project-nvim = {
          enable = true;
          enableTelescope = true;
          settings = {
            use_lsp = true;
            patterns = [
              ".git"
              ".hg"
              ".bzr"
              ".svn"
              "Makefile"
              "Dockerfile"
              "docker-compose.yml"
              "docker-compose.yaml"
              "package.json"
              "flake.nix"
              "default.nix"
              "shell.nix"
              "pyproject.toml"
              "Cargo.toml"
              "go.mod"
              "CMakeLists.txt"
              ".project"
            ];

            show_hidden = self.settings.showHidden;
            silent_chdir = true;
            scope_chdir = if self.settings.changeDirGlobally then "global" else "tab";
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>p";
            action = "<cmd>Telescope projects<CR>";
            options = {
              silent = true;
              desc = "Find projects";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>p";
            desc = "Find projects";
            icon = "󰉋";
          }
        ];
      };
    };
}
