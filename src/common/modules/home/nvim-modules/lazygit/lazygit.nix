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
  name = "lazygit";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      git = {
        lazygit = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          lazygit-nvim
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>gl";
            action = "<cmd>lua require('lazygit').lazygit()<CR>";
            options = {
              silent = true;
              desc = "Open LazyGit";
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>gl";
            desc = "Open LazyGit";
            icon = "";
          }
        ];
      };
    };
}
