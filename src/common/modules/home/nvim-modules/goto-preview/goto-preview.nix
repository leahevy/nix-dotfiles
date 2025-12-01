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
  name = "goto-preview";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    width = 120;
    height = 15;
    border = [
      "↖"
      "─"
      "┐"
      "│"
      "┘"
      "─"
      "└"
      "│"
    ];
    debug = false;
    opacity = null;
    resizing_mappings = false;
    post_open_hook = null;
    post_close_hook = null;
    references = {
      provider = "telescope";
    };
    focus_on_open = true;
    dismiss_on_move = false;
    force_close = true;
    bufhidden = "wipe";
    stack_floating_preview_windows = true;
    same_file_float_preview = true;
    preview_window_title = {
      enable = true;
      position = "left";
    };
    zindex = 1;
    vim_ui_input = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.goto-preview = {
          enable = true;
          settings = {
            width = self.settings.width;
            height = self.settings.height;
            border = self.settings.border;
            default_mappings = false;
            debug = self.settings.debug;
            opacity = self.settings.opacity;
            resizing_mappings = self.settings.resizing_mappings;
            post_open_hook = self.settings.post_open_hook;
            post_close_hook = self.settings.post_close_hook;
            references = self.settings.references;
            focus_on_open = self.settings.focus_on_open;
            dismiss_on_move = self.settings.dismiss_on_move;
            force_close = self.settings.force_close;
            bufhidden = self.settings.bufhidden;
            stack_floating_preview_windows = self.settings.stack_floating_preview_windows;
            same_file_float_preview = self.settings.same_file_float_preview;
            preview_window_title = self.settings.preview_window_title;
            zindex = self.settings.zindex;
            vim_ui_input = self.settings.vim_ui_input;
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "gpd";
            action.__raw = "function() require('goto-preview').goto_preview_definition() end";
            options = {
              desc = "Preview definition";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "gpt";
            action.__raw = "function() require('goto-preview').goto_preview_type_definition() end";
            options = {
              desc = "Preview type definition";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "gpi";
            action.__raw = "function() require('goto-preview').goto_preview_implementation() end";
            options = {
              desc = "Preview implementation";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "gpD";
            action.__raw = "function() require('goto-preview').goto_preview_declaration() end";
            options = {
              desc = "Preview declaration";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "gpp";
            action.__raw = "function() require('goto-preview').close_all_win() end";
            options = {
              desc = "Close all preview windows";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "gpr";
            action.__raw = "function() require('goto-preview').goto_preview_references() end";
            options = {
              desc = "Preview references";
              silent = true;
            };
          }
        ];

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "gp";
            group = "Preview";
            icon = "👁️";
          }
          {
            __unkeyed-1 = "gpd";
            desc = "Definition";
            icon = "🎯";
          }
          {
            __unkeyed-1 = "gpt";
            desc = "Type Definition";
            icon = "🔤";
          }
          {
            __unkeyed-1 = "gpi";
            desc = "Implementation";
            icon = "⚙️";
          }
          {
            __unkeyed-1 = "gpD";
            desc = "Declaration";
            icon = "📝";
          }
          {
            __unkeyed-1 = "gpp";
            desc = "Close All";
            icon = "❌";
          }
          {
            __unkeyed-1 = "gpr";
            desc = "References";
            icon = "🔗";
          }
        ];
      };
    };
}
