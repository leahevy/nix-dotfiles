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
  name = "calendar";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          mattn-calendar-vim
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>C";
            action = ":Calendar<CR>";
            options = {
              desc = "Open calendar";
              silent = true;
            };
          }
        ];
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>C";
              desc = "Open calendar";
              icon = "📅";
            }
          ];
    };
}
