args@{
  lib,
  pkgs,
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

  settings = {
    autoDetectProjects = true;
    maxProjects = 50;
    showHidden = false;
    changeDirGlobally = true;
  };

  module = {
    home = config: {
      programs.nixvim = {
        plugins.project-nvim = {
          enable = true;
          enableTelescope = true;
          package = pkgs.vimPlugins.project-nvim.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace lua/project/util/history.lua \
                --replace \
                "Defering call to \`%s.write_history()\`'):format(MODSTR)" \
                "Deferring call to \`write_history()\`'):format(MODSTR)"
            '';
          });
          settings = {
            lsp = {
              enabled = true;
            };
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
  };
}
