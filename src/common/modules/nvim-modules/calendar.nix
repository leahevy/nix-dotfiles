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

  settings = {
    mondayIsFirstWeekday = true;
    markAlignment = "left-fit";
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          mattn-calendar-vim
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["10-calendar-config"] = function()
            ${lib.optionalString self.settings.mondayIsFirstWeekday "vim.g.calendar_monday = 1"}
            vim.g.calendar_mark = "${self.settings.markAlignment}"
          end
        '';

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
