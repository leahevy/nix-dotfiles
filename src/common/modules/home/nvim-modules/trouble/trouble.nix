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
  name = "trouble";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    autoClose = false;
    autoJump = false;
    autoPreview = true;
    focus = true;
    followCursor = true;
    restoreLastLocation = true;
    multiline = true;
    maxItems = 200;
    winConfig = {
      border = "rounded";
      title = "Trouble";
      title_pos = "center";
    };
    icons = {
      folder_closed = " ";
      folder_open = " ";
      indent = {
        fold_closed = " ";
        fold_open = " ";
        last = "└╴";
        middle = "├╴";
        top = "│ ";
        ws = "  ";
      };
      kinds = {
        Array = " ";
        Boolean = "󰨙 ";
        Class = " ";
        Constant = "󰏿 ";
        Constructor = " ";
        Enum = " ";
        EnumMember = " ";
        Event = " ";
        Field = " ";
        File = " ";
        Function = "󰊕 ";
        Interface = " ";
        Key = " ";
        Method = "󰊕 ";
        Module = " ";
        Namespace = "󰦮 ";
        Null = " ";
        Number = "󰎠 ";
        Object = " ";
        Operator = " ";
        Package = " ";
        Property = " ";
        String = " ";
        Struct = "󰆼 ";
        TypeParameter = " ";
        Variable = "󰀫 ";
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.trouble = {
          enable = true;
          settings = {
            auto_close = self.settings.autoClose;
            auto_jump = self.settings.autoJump;
            auto_preview = self.settings.autoPreview;
            focus = self.settings.focus;
            follow = self.settings.followCursor;
            restore = self.settings.restoreLastLocation;
            multiline = self.settings.multiline;
            max_items = self.settings.maxItems;
            win = self.settings.winConfig;
            icons = self.settings.icons;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>aa";
            action = "<cmd>Trouble diagnostics toggle<cr>";
            options = {
              desc = "Workspace diagnostics";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>ab";
            action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
            options = {
              desc = "Buffer diagnostics";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>as";
            action = "<cmd>Trouble symbols toggle focus=false<cr>";
            options = {
              desc = "Document symbols";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>al";
            action = "<cmd>Trouble lsp toggle focus=false win.position=right<cr>";
            options = {
              desc = "LSP definitions/references";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>aq";
            action = "<cmd>Trouble qflist toggle<cr>";
            options = {
              desc = "Quickfix list";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>aL";
            action = "<cmd>Trouble loclist toggle<cr>";
            options = {
              desc = "Location list";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>a";
            group = "Trouble";
            icon = "🚦";
          }
          {
            __unkeyed-1 = "<leader>aa";
            desc = "Workspace diagnostics";
            icon = "🌍";
          }
          {
            __unkeyed-1 = "<leader>ab";
            desc = "Buffer diagnostics";
            icon = "📄";
          }
          {
            __unkeyed-1 = "<leader>as";
            desc = "Document symbols";
            icon = "🔍";
          }
          {
            __unkeyed-1 = "<leader>al";
            desc = "LSP definitions/references";
            icon = "🔗";
          }
          {
            __unkeyed-1 = "<leader>aq";
            desc = "Quickfix list";
            icon = "🔧";
          }
          {
            __unkeyed-1 = "<leader>aL";
            desc = "Location list";
            icon = "📍";
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["85-trouble-colors"] = function()
            vim.api.nvim_set_hl(0, "TroubleNormal", { bg = "${config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html}" })
          end
        '';
      };
    };
}
