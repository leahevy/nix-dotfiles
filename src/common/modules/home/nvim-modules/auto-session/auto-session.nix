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
  name = "auto-session";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    autoSave = true;
    autoRestore = true;
    autoCreate = true;
    suppressedDirs = [
      "~/"
      "/tmp"
    ];
    cwdChangeHandling = false;
    logLevel = "error";
    sessionLensLoadOnSetup = true;

    ignoredBufferTypes = [
      "terminal"
      "nofile"
      "nowrite"
      "prompt"
      "help"
      "quickfix"
      "man"
    ];

    bypassSaveFiletypes = [
      "dashboard"
      "alpha"
      "netrw"
      "toggleterm"
      "Codewindow"
      "terminal"
      "help"
      "qf"
      "prompt"
      "nofile"
      "nowrite"
      "man"
      "notify"
      "yazi"
      "trouble"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/10-auto-session-setup.lua".text = ''
        local function clean_session_file(file_path)
          if vim.fn.filereadable(file_path) == 1 then
            local lines = vim.fn.readfile(file_path)
            local modified = false
            local ignored_types = {${
              lib.concatMapStringsSep ", " (t: "\"" + t + "\"") self.settings.ignoredBufferTypes
            }}

            for i, line in ipairs(lines) do
              if line:match("^setlocal buftype=") then
                for _, ignored_type in ipairs(ignored_types) do
                  if line == "setlocal buftype=" .. ignored_type then
                    lines[i] = '" ' .. line
                    modified = true
                    break
                  end
                end
              end
            end

            if modified then
              vim.fn.writefile(lines, file_path)
            end
          end
        end

        local session_dir = vim.fn.stdpath("data") .. "/sessions/"
        local cwd = vim.fn.getcwd()
        local session_name = cwd:gsub("([^A-Za-z0-9])", function(c)
          return string.format("%%%02X", string.byte(c))
        end)
        local session_file = session_dir .. session_name .. ".vim"
        clean_session_file(session_file)

        require("auto-session").setup({
          enabled = ${if self.settings.autoRestore then "true" else "false"},
          auto_save = ${if self.settings.autoSave then "true" else "false"},
          auto_restore = false,
          auto_create = ${if self.settings.autoCreate then "true" else "false"},
          suppressed_dirs = {${
            lib.concatMapStringsSep ", " (d: "\"" + d + "\"") self.settings.suppressedDirs
          }},
          use_git_branch = false,
          cwd_change_handling = ${if self.settings.cwdChangeHandling then "true" else "false"},
          log_level = "${self.settings.logLevel}",
          close_unsupported_windows = true,
          bypass_save_filetypes = {${
            lib.concatMapStringsSep ", " (t: "\"" + t + "\"") self.settings.bypassSaveFiletypes
          }},

          pre_save_cmds = {
            function()
              if vim.fn.exists(":NvimTreeClose") == 2 then
                vim.cmd("tabdo NvimTreeClose")
              end

              local ignored_types = {${
                lib.concatMapStringsSep ", " (t: "\"" + t + "\"") self.settings.ignoredBufferTypes
              }}
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                local buftype = vim.bo[buf].buftype
                for _, ignored_type in ipairs(ignored_types) do
                  if buftype == ignored_type then
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                    break
                  end
                end
              end
            end
          },

          post_restore_cmds = {
            function()
              local ignored_types = {${
                lib.concatMapStringsSep ", " (t: "\"" + t + "\"") self.settings.ignoredBufferTypes
              }}
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                local bufname = vim.api.nvim_buf_get_name(buf)
                local buftype = vim.bo[buf].buftype

                local is_ignored = false
                for _, ignored_type in ipairs(ignored_types) do
                  if buftype == ignored_type and ignored_type ~= "help" then
                    is_ignored = true
                    break
                  end
                end

                if is_ignored then
                  pcall(vim.api.nvim_buf_delete, buf, { force = true })
                elseif bufname ~= "" and not bufname:match("^%w+://") then
                  if vim.fn.filereadable(bufname) ~= 1 then
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                  end
                end
              end
            end
          },

          session_lens = {
            load_on_setup = ${if self.settings.sessionLensLoadOnSetup then "true" else "false"},
            previewer = false,
            picker_opts = {
              layout_strategy = "horizontal",
              layout_config = {
                width = 0.8,
                height = 0.8,
              },
            },
          },
        })

        ${
          if self.settings.autoRestore then
            ''
              if #vim.fn.argv() == 0 then
                local session_dir = vim.fn.stdpath("data") .. "/sessions/"
                local cwd = vim.fn.getcwd()
                local session_name = cwd:gsub("([^A-Za-z0-9])", function(c)
                  return string.format("%%%02X", string.byte(c))
                end)
                local session_file = session_dir .. session_name .. ".vim"
                local session_exists = vim.fn.filereadable(session_file) == 1

                if session_exists then
                  vim.defer_fn(function()
                    local should_skip = false

                    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                      local bufname = vim.api.nvim_buf_get_name(buf)

                      if bufname:match("^%w+://") then
                        should_skip = true
                        break
                      end

                      if bufname == "" then
                        local line_count = vim.api.nvim_buf_line_count(buf)
                        local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
                        if line_count > 1 or first_line ~= "" then
                          should_skip = true
                          break
                        end
                      end
                    end

                    if not should_skip then
                      clean_session_file(session_file)
                      require("auto-session").RestoreSession()
                    end
                  end, 10)
                end
              end
            ''
          else
            ""
        }
      '';

      programs.nixvim = {
        opts = {
          sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,localoptions";
        };

        extraPlugins = with pkgs.vimPlugins; [
          auto-session
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>So";
            action = "<cmd>Telescope session-lens<CR>";
            options = {
              silent = true;
              desc = "Open session picker";
            };
          }
          {
            mode = "n";
            key = "<leader>Sd";
            action = "<cmd>Autosession deletePicker<CR>";
            options = {
              silent = true;
              desc = "Delete session picker";
            };
          }
          {
            mode = "n";
            key = "<leader>Sc";
            action = ":Autosession save ";
            options = {
              silent = false;
              desc = "Save named session";
            };
          }
          {
            mode = "n";
            key = "<leader>Ss";
            action = "<cmd>Autosession save<CR>";
            options = {
              silent = true;
              desc = "Save current session";
            };
          }
          {
            mode = "n";
            key = "<leader>Sr";
            action = "<cmd>lua require('auto-session').RestoreSession(vim.fn.getcwd())<CR>";
            options = {
              silent = true;
              desc = "Restore session for current directory";
            };
          }
        ];
      };

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>S";
              group = "session";
              icon = "󰆓";
            }
            {
              __unkeyed-1 = "<leader>So";
              desc = "Open session picker";
              icon = "󰋚";
            }
            {
              __unkeyed-1 = "<leader>Sd";
              desc = "Delete session";
              icon = "󰆴";
            }
            {
              __unkeyed-1 = "<leader>Sc";
              desc = "Save named session";
              icon = "󰆓";
            }
            {
              __unkeyed-1 = "<leader>Ss";
              desc = "Save current session";
              icon = "󰆓";
            }
            {
              __unkeyed-1 = "<leader>Sr";
              desc = "Restore session for cwd";
              icon = "󰦛";
            }
          ];
    };
}
