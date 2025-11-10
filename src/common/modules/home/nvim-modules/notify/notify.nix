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
  name = "notify";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    timeout = 10000;
    max_width = 75;
    max_height = 20;
    stages = "fade_in_slide_out";
    render = "wrapped-compact";
    background_colour = "#000000";
    fps = 30;
    level = "debug";
    minimum_width = 50;
    top_down = true;
    icons = {
      debug = "";
      error = "";
      info = "";
      trace = "✎";
      warn = "";
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim.plugins.notify = {
        enable = true;
        settings = {
          timeout = self.settings.timeout;
          max_width = self.settings.max_width;
          max_height = self.settings.max_height;
          stages = self.settings.stages;
          render = self.settings.render;
          background_colour = self.settings.background_colour;
          fps = self.settings.fps;
          level = self.settings.level;
          minimum_width = self.settings.minimum_width;
          top_down = self.settings.top_down;
          icons = self.settings.icons;
        };
      };

      programs.nixvim.keymaps = [
        {
          mode = "n";
          key = "<leader>ul";
          action = "<cmd>Telescope notify<cr>";
          options = {
            desc = "Notification History";
            silent = true;
          };
        }
        {
          mode = "n";
          key = "<leader>ud";
          action = "<cmd>lua for _, buf in ipairs(vim.api.nvim_list_bufs()) do if vim.api.nvim_buf_get_option(buf, 'filetype') == 'notify' then vim.api.nvim_buf_delete(buf, {}) end end<cr>";
          options = {
            desc = "Dismiss";
            silent = true;
          };
        }
      ];

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>u";
              group = "Notifications";
              icon = "🔔";
            }
            {
              __unkeyed-1 = "<leader>ul";
              desc = "History";
              icon = "📋";
            }
            {
              __unkeyed-1 = "<leader>ud";
              desc = "Close Buffers";
              icon = "🗑️";
            }
          ];

      home.file.".config/nvim-init/60-notify.lua".text = ''
        vim.notify = require("notify")

        local function fix_notify_background()
          vim.api.nvim_set_hl(0, "NotifyBackground", { bg = "${self.settings.background_colour}" })
          vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = "#8A1F1F" })
          vim.api.nvim_set_hl(0, "NotifyWARNBorder", { fg = "#79491D" })
          vim.api.nvim_set_hl(0, "NotifyINFOBorder", { fg = "#4F6752" })
          vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { fg = "#8B8B8B" })
          vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { fg = "#4F3552" })
          vim.api.nvim_set_hl(0, "NotifyERRORIcon", { fg = "#F70067" })
          vim.api.nvim_set_hl(0, "NotifyWARNIcon", { fg = "#F79000" })
          vim.api.nvim_set_hl(0, "NotifyINFOIcon", { fg = "#A9FF68" })
          vim.api.nvim_set_hl(0, "NotifyDEBUGIcon", { fg = "#8B8B8B" })
          vim.api.nvim_set_hl(0, "NotifyTRACEIcon", { fg = "#D484FF" })
          vim.api.nvim_set_hl(0, "NotifyERRORTitle", { fg = "#F70067" })
          vim.api.nvim_set_hl(0, "NotifyWARNTitle", { fg = "#F79000" })
          vim.api.nvim_set_hl(0, "NotifyINFOTitle", { fg = "#A9FF68" })
          vim.api.nvim_set_hl(0, "NotifyDEBUGTitle", { fg = "#8B8B8B" })
          vim.api.nvim_set_hl(0, "NotifyTRACETitle", { fg = "#D484FF" })
          vim.api.nvim_set_hl(0, "NotifyERRORBody", { fg = "#FFFFFF", bg = "${self.settings.background_colour}" })
          vim.api.nvim_set_hl(0, "NotifyWARNBody", { fg = "#FFFFFF", bg = "${self.settings.background_colour}" })
          vim.api.nvim_set_hl(0, "NotifyINFOBody", { fg = "#FFFFFF", bg = "${self.settings.background_colour}" })
          vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { fg = "#FFFFFF", bg = "${self.settings.background_colour}" })
          vim.api.nvim_set_hl(0, "NotifyTRACEBody", { fg = "#FFFFFF", bg = "${self.settings.background_colour}" })
        end

        vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
          callback = function()
            vim.defer_fn(fix_notify_background, 150)
          end,
        })
      '';
    };
}
