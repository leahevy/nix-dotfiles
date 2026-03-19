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
  name = "arrow";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    showIcons = true;
    alwaysShowPath = false;
    globalBookmarks = false;
    separateByBranch = true;
    hideHandbook = false;
    hideBufferHandbook = false;
    saveKey = "git_root";
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.arrow = {
          enable = true;
          settings = {
            show_icons = self.settings.showIcons;
            always_show_path = self.settings.alwaysShowPath;
            global_bookmarks = self.settings.globalBookmarks;
            separate_by_branch = self.settings.separateByBranch;
            hide_handbook = self.settings.hideHandbook;
            hide_buffer_handbook = self.settings.hideBufferHandbook;
            leader_key = "<M-Space>";
            buffer_leader_key = "<C-g>";
            save_key = self.settings.saveKey;
            index_keys = "123456789zxcbnmZXVBNM,./;";
            separate_save_and_remove = true;
            mappings = {
              edit = "e";
              delete_mode = "d";
              clear_all_items = "C";
              toggle = "s";
              open_vertical = "v";
              open_horizontal = "h";
              quit = "q";
              remove = "x";
              next_item = "j";
              prev_item = "k";
            };
            window = {
              width = "auto";
              height = "auto";
              row = "auto";
              col = "auto";
              border = "rounded";
            };
          };
        };

        keymaps = [
          {
            mode = "n";
            key = "<leader>,";
            action = "<cmd>lua require('arrow.persist').previous()<cr>";
            options = {
              desc = "Previous arrow bookmark";
              silent = true;
            };
          }
          {
            mode = "n";
            key = "<leader>.";
            action = "<cmd>lua require('arrow.persist').next()<cr>";
            options = {
              desc = "Next arrow bookmark";
              silent = true;
            };
          }
        ];
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<M-Space>";
              desc = "Toggle bookmarks";
              icon = "🏹";
            }
            {
              __unkeyed-1 = "<C-g>";
              desc = "Buffer bookmarks";
              icon = "📋";
            }
            {
              __unkeyed-1 = "<leader>,";
              desc = "Previous bookmark";
              icon = "◀";
            }
            {
              __unkeyed-1 = "<leader>.";
              desc = "Next bookmark";
              icon = "▶";
            }
          ];
    };
}
