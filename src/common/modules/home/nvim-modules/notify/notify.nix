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
    timeout = 6000;
    max_width = 75;
    max_height = 75;
    stages = "fade_in_slide_out";
    render = "wrapped-default";
    background_colour = "#000000";
    fps = 30;
    level = "debug";
    minimum_width = 25;
    top_down = true;
    addEventNotifications = true;
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
          render.__raw = ''"${self.settings.render}"'';
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

        ${lib.optionalString self.settings.addEventNotifications ''
          local write_failed = {}
          local was_modified = {}

          vim.api.nvim_create_autocmd("BufWritePost", {
            callback = function()
              local bufnr = vim.api.nvim_get_current_buf()
              if not write_failed[bufnr] and was_modified[bufnr] then
                local filename = vim.fn.expand("%:t")

                if _G.autosave_in_progress then
                  vim.notify("🔄 Auto-saved: " .. filename, vim.log.levels.INFO, {
                    title = "Auto Save",
                    timeout = 1
                  })
                else
                  vim.notify("💾 Path: " .. filename, vim.log.levels.INFO, {
                    title = "File Saved"
                  })
                end
              end
              write_failed[bufnr] = nil
              was_modified[bufnr] = nil
            end,
          })

          vim.api.nvim_create_autocmd("BufReadPost", {
            callback = function()
              local filepath = vim.fn.expand("%:p")
              local filesize = vim.fn.getfsize(filepath)
              if filesize > 5000000 then
                vim.defer_fn(function()
                  local size_mb = math.floor(filesize / 1024 / 1024 * 100) / 100
                  vim.notify("⚠️ Large file loaded: " .. size_mb .. "MB", vim.log.levels.WARN, {
                    title = "Performance Warning"
                  })
                end, 100)
              end
            end,
          })

          local lsp_state = {}

          local function handle_lsp_event(client_name, event_type)
            local current_time = vim.loop.now()
            local state = lsp_state[client_name] or {}

            if state.timer then
              pcall(vim.fn.timer_stop, state.timer)
              state.timer = nil
            end

            if state.last_event and current_time - state.last_time < 3000 then
              if state.last_event ~= event_type then
                vim.notify("🔄 " .. client_name .. " reconnected", vim.log.levels.INFO, {
                  title = "LSP"
                })
                lsp_state[client_name] = nil
                return
              end
            end

            lsp_state[client_name] = {
              last_event = event_type,
              last_time = current_time,
              timer = vim.fn.timer_start(3000, function()
                if event_type == "attach" then
                  vim.notify("✅ " .. client_name .. " connected", vim.log.levels.INFO, {
                    title = "LSP"
                  })
                else
                  vim.notify("❌ " .. client_name .. " disconnected", vim.log.levels.WARN, {
                    title = "LSP"
                  })
                end
                lsp_state[client_name] = nil
              end)
            }
          end

          vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(event)
              local client = vim.lsp.get_client_by_id(event.data.client_id)
              if client then
                vim.defer_fn(function()
                  handle_lsp_event(client.name, "attach")
                end, 100)
              end
            end,
          })

          vim.api.nvim_create_autocmd("LspDetach", {
            callback = function(event)
              local client = vim.lsp.get_client_by_id(event.data.client_id)
              if client then
                vim.defer_fn(function()
                  handle_lsp_event(client.name, "detach")
                end, 100)
              end
            end,
          })

          vim.api.nvim_create_autocmd("DirChanged", {
            callback = function(event)
              local new_dir = vim.fn.fnamemodify(event.file, ":t")
              vim.notify("🏠 New working directory: " .. new_dir, vim.log.levels.INFO, {
                title = "Directory Changed"
              })
            end,
          })

          local session_checked = false
          local function check_for_session()
            if session_checked then return end

            if _G.session_was_restored then
              local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
              vim.notify("👋 Welcome to " .. project_name, vim.log.levels.INFO, {
                title = "Session Restored"
              })
              session_checked = true
            end
          end

          vim.api.nvim_create_autocmd("VimEnter", {
            once = true,
            callback = function()
              vim.defer_fn(check_for_session, 1000)
              vim.defer_fn(check_for_session, 2000)
            end,
          })

          vim.api.nvim_create_autocmd("BufWritePre", {
            callback = function()
              local bufnr = vim.api.nvim_get_current_buf()
              was_modified[bufnr] = vim.bo.modified
              if vim.bo.readonly then
                write_failed[bufnr] = true
                vim.notify("🚫 Cannot save readonly file", vim.log.levels.ERROR, {
                  title = "Write Error"
                })
              else
                write_failed[bufnr] = false
              end
            end,
          })
        ''}
      '';
    };
}
