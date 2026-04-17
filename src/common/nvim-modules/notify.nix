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

  settings = {
    timeout = 3000;
    max_width = 75;
    max_height = 75;
    stages = "fade_in_slide_out";
    render = "wrapped-default";
    background_colour = null;
    fps = 30;
    level = "debug";
    minimum_width = 15;
    top_down = true;
    addEventNotifications = true;
    icons = {
      debug = "";
      error = "";
      info = "";
      trace = "✎";
      warn = "";
    };
    lspsToIgnoreInNotifications = [
      "GitHub Copilot"
    ];
  };

  module = {
    home =
      config:
      let
        theme = config.nx.preferences.theme;
        background_colour =
          if self.settings.background_colour != null then
            self.settings.background_colour
          else
            theme.colors.terminal.normalBackgrounds.primary.html;
      in
      {
        programs.nixvim.plugins.notify = {
          enable = true;
          settings = {
            timeout = self.settings.timeout;
            max_width = self.settings.max_width;
            max_height = self.settings.max_height;
            stages = self.settings.stages;
            render.__raw = ''"${self.settings.render}"'';
            background_colour = background_colour;
            fps = self.settings.fps;
            level = self.settings.level;
            minimum_width = self.settings.minimum_width;
            top_down = self.settings.top_down;
            icons = self.settings.icons;
          };
        };

        programs.nixvim.autoCmd = [
          {
            event = [ "FileType" ];
            pattern = [ "notify" ];
            callback = {
              __raw = ''
                function()
                  vim.keymap.set('n', 'q', ':close<CR>', { buffer = true, silent = true })
                end
              '';
            };
          }
        ];

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

        programs.nixvim.extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["60-notify"] = function()
            vim.notify = require("notify")

            local function fix_notify_background()
              vim.api.nvim_set_hl(0, "NotifyBackground", { bg = "${background_colour}" })
              vim.api.nvim_set_hl(0, "NotifyERRORBorder", { fg = "${config.nx.preferences.theme.colors.semantic.removed.html}" })
              vim.api.nvim_set_hl(0, "NotifyWARNBorder", { fg = "${config.nx.preferences.theme.colors.semantic.hint.html}" })
              vim.api.nvim_set_hl(0, "NotifyINFOBorder", { fg = "${config.nx.preferences.theme.colors.separators.normal.html}" })
              vim.api.nvim_set_hl(0, "NotifyDEBUGBorder", { fg = "${config.nx.preferences.theme.colors.separators.light.html}" })
              vim.api.nvim_set_hl(0, "NotifyTRACEBorder", { fg = "${config.nx.preferences.theme.colors.separators.dark.html}" })
              vim.api.nvim_set_hl(0, "NotifyERRORIcon", { fg = "${config.nx.preferences.theme.colors.semantic.error.html}" })
              vim.api.nvim_set_hl(0, "NotifyWARNIcon", { fg = "${config.nx.preferences.theme.colors.semantic.warning.html}" })
              vim.api.nvim_set_hl(0, "NotifyINFOIcon", { fg = "${config.nx.preferences.theme.colors.semantic.info.html}" })
              vim.api.nvim_set_hl(0, "NotifyDEBUGIcon", { fg = "${config.nx.preferences.theme.colors.separators.light.html}" })
              vim.api.nvim_set_hl(0, "NotifyTRACEIcon", { fg = "${config.nx.preferences.theme.colors.terminal.colors.magenta.html}" })
              vim.api.nvim_set_hl(0, "NotifyERRORTitle", { fg = "${config.nx.preferences.theme.colors.semantic.error.html}" })
              vim.api.nvim_set_hl(0, "NotifyWARNTitle", { fg = "${config.nx.preferences.theme.colors.semantic.warning.html}" })
              vim.api.nvim_set_hl(0, "NotifyINFOTitle", { fg = "${config.nx.preferences.theme.colors.semantic.info.html}" })
              vim.api.nvim_set_hl(0, "NotifyDEBUGTitle", { fg = "${config.nx.preferences.theme.colors.separators.light.html}" })
              vim.api.nvim_set_hl(0, "NotifyTRACETitle", { fg = "${config.nx.preferences.theme.colors.terminal.colors.magenta.html}" })
              vim.api.nvim_set_hl(0, "NotifyERRORBody", { fg = "${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}", bg = "${background_colour}" })
              vim.api.nvim_set_hl(0, "NotifyWARNBody", { fg = "${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}", bg = "${background_colour}" })
              vim.api.nvim_set_hl(0, "NotifyINFOBody", { fg = "${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}", bg = "${background_colour}" })
              vim.api.nvim_set_hl(0, "NotifyDEBUGBody", { fg = "${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}", bg = "${background_colour}" })
              vim.api.nvim_set_hl(0, "NotifyTRACEBody", { fg = "${config.nx.preferences.theme.colors.terminal.foregrounds.primary.html}", bg = "${background_colour}" })
            end

            local startup_time = vim.loop.now()

            vim.api.nvim_create_autocmd({"VimEnter", "ColorScheme"}, {
              callback = function()
                fix_notify_background()
                vim.defer_fn(fix_notify_background, 100)
              end,
            })

            ${lib.optionalString self.settings.addEventNotifications ''
              local write_failed = {}
              local was_modified = {}
              local last_write_time = {}

              vim.api.nvim_create_autocmd("BufWritePost", {
                callback = function()
                  local bufnr = vim.api.nvim_get_current_buf()
                  if not write_failed[bufnr] and was_modified[bufnr] then
                    local filename = vim.fn.expand("%:t")
                    if _G.autosave_in_progress then
                      vim.notify("Auto-saved: " .. filename, vim.log.levels.INFO, {
                        icon = "💾",
                        title = "Auto Save",
                        timeout = 1
                      })
                    else
                      vim.notify("Manually saved: " .. filename, vim.log.levels.INFO, {
                        icon = "💾",
                        title = "File Saved"
                      })
                    end
                  end
                  last_write_time[bufnr] = vim.loop.now()
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
                      vim.notify("Large file loaded: " .. size_mb .. "MB", vim.log.levels.WARN, {
                        icon = "⚠️",
                        title = "Performance Warning"
                      })
                    end, 100)
                  end
                end,
              })

              local lsp_state = {}

              local lsps_to_ignore = {
                ${lib.concatStringsSep ", " (
                  lib.map (name: "\"${name}\"") self.settings.lspsToIgnoreInNotifications
                )}
              }

              local function handle_lsp_event(client_name, event_type)
                local current_time = vim.loop.now()
                local state = lsp_state[client_name] or {}

                if state.timer then
                  pcall(vim.fn.timer_stop, state.timer)
                  state.timer = nil
                end

                if state.last_event and current_time - state.last_time < 1000 then
                  if state.last_event ~= event_type then
                    if not vim.tbl_contains(lsps_to_ignore, client_name) then
                      vim.notify(client_name .. " reconnected", vim.log.levels.INFO, {
                        icon = "🤖",
                        title = "LSP"
                      })
                    end
                    lsp_state[client_name] = nil
                    return
                  end
                end

                lsp_state[client_name] = {
                  last_event = event_type,
                  last_time = current_time,
                  timer = vim.fn.timer_start(1000, function()
                    if event_type == "attach" then
                      if not vim.tbl_contains(lsps_to_ignore, client_name) then
                        vim.notify(client_name .. " connected", vim.log.levels.INFO, {
                          icon = "🤖",
                          title = "LSP"
                        })
                      end
                    else
                      if not vim.tbl_contains(lsps_to_ignore, client_name) then
                        vim.notify(client_name .. " disconnected", vim.log.levels.WARN, {
                          icon = "🤖",
                          title = "LSP"
                        })
                      end
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
                  local current_time = vim.loop.now()
                  if current_time - startup_time < 5000 then
                    return
                  end

                  local new_dir = vim.fn.fnamemodify(event.file, ":t")
                  vim.defer_fn(function()
                    vim.notify("New working directory: " .. new_dir, vim.log.levels.INFO, {
                      icon = "🏠",
                      title = "Directory Changed"
                    })
                  end, 50)
                end,
              })

              local session_checked = false
              local function check_for_session()
                if session_checked then return end

                if _G.session_was_restored then
                  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
                  vim.notify("Welcome to " .. project_name, vim.log.levels.INFO, {
                    icon = "👋",
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
                  local current_time = vim.loop.now()

                  local actually_modified = vim.bo[bufnr].modified
                  local time_since_last_write = last_write_time[bufnr] and (current_time - last_write_time[bufnr]) or 999999

                  was_modified[bufnr] = actually_modified or time_since_last_write > 1000

                  if vim.bo.readonly then
                    write_failed[bufnr] = true
                    vim.notify("Cannot save readonly file", vim.log.levels.ERROR, {
                      icon = "🚫",
                      title = "Write Error"
                    })
                  else
                    write_failed[bufnr] = false
                  end
                end,
              })
            ''}
          end
        '';
      };
  };
}
