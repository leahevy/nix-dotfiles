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
  name = "yazi";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    openForDirectories = false;
    floatingWindowScalingFactor = 0.9;
    yaziFloatingWindowBorder = "rounded";
    yaziFloatingWindowWinblend = 0;
    enableMouseSupport = false;
    clipboardRegister = "+";
  };

  submodules = {
    common = {
      shell = {
        yazi = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.yazi = {
          enable = true;
          settings = {
            open_for_directories = self.settings.openForDirectories;
            floating_window_scaling_factor = self.settings.floatingWindowScalingFactor;
            yazi_floating_window_border = self.settings.yaziFloatingWindowBorder;
            yazi_floating_window_winblend = self.settings.yaziFloatingWindowWinblend;
            enable_mouse_support = self.settings.enableMouseSupport;
            clipboard_register = self.settings.clipboardRegister;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>yy";
            action = "<cmd>Yazi<cr>";
            options = {
              desc = "Open yazi (current file)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>yw";
            action = "<cmd>Yazi cwd<cr>";
            options = {
              desc = "Open yazi (working directory)";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>yt";
            action = "<cmd>Yazi toggle<cr>";
            options = {
              desc = "Resume yazi session";
              silent = true;
            };
          }
        ];
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>y";
              group = "Yazi";
              icon = "📁";
            }
            {
              __unkeyed-1 = "<leader>yy";
              desc = "Current file";
              icon = "📄";
            }
            {
              __unkeyed-1 = "<leader>yw";
              desc = "Working directory";
              icon = "📂";
            }
            {
              __unkeyed-1 = "<leader>yt";
              desc = "Resume session";
              icon = "🔄";
            }
          ];
    };
}
