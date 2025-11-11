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
        _G.session_was_restored = false

        _G.get_canonical_path = function(path)
          local resolved = vim.fn.resolve(path or vim.fn.getcwd())
          return vim.fn.fnamemodify(resolved, ':p'):gsub('/$', "")
        end

        local function encode_session_name(path)
          return path:gsub("([/\\:*?\"'<>+ |%.%%])", function(c)
            return string.format("%%%02X", string.byte(c))
          end)
        end

        local function find_session_file(cwd)
          local session_dir = vim.fn.stdpath("data") .. "/sessions/"

          local current_session = session_dir .. encode_session_name(cwd) .. ".vim"
          if vim.fn.filereadable(current_session) == 1 then
            return current_session, cwd
          end

          local canonical = _G.get_canonical_path(cwd)
          local canonical_session = session_dir .. encode_session_name(canonical) .. ".vim"
          if vim.fn.filereadable(canonical_session) == 1 then
            return canonical_session, canonical
          end

          return nil, canonical
        end

        local function clean_session_file(file_path, target_cwd)
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
              elseif target_cwd and (line:match("^cd ") or line:match("^lcd ")) then
                local old_path = line:match("^l?cd (.+)$")
                local cmd_type = line:match("^(l?cd) ")
                if old_path and (vim.fn.isdirectory(vim.fn.expand(old_path)) == 0 or old_path ~= target_cwd) then
                  lines[i] = cmd_type .. " " .. target_cwd
                  modified = true
                end
              end
            end

            if modified then
              vim.fn.writefile(lines, file_path)
            end
          end
        end

        local session_dir = vim.fn.stdpath("data") .. "/sessions/"
        local canonical_cwd = _G.get_canonical_path()
        local session_name = encode_session_name(canonical_cwd)
        local session_file = session_dir .. session_name .. ".vim"
        clean_session_file(session_file, canonical_cwd)

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
                local cwd = vim.fn.getcwd()
                local session_file, canonical_path = find_session_file(cwd)
                local session_exists = session_file ~= nil

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
                      clean_session_file(session_file, canonical_path)
                      require("auto-session").RestoreSession()
                      _G.session_was_restored = true
                    end
                  end, 10)
                end
              end
            ''
          else
            ""
        }

        function _G.save_session_with_notify()
          local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          vim.cmd("Autosession save")
          vim.notify("💾 Session saved for " .. project_name, vim.log.levels.INFO, {
            title = "Session"
          })
        end

        function _G.restore_session_with_notify()
          local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
          require('auto-session').RestoreSession(_G.get_canonical_path())
          vim.notify("📂 Session restored for " .. project_name, vim.log.levels.INFO, {
            title = "Session"
          })
        end
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
            action = "<cmd>lua _G.save_session_with_notify()<CR>";
            options = {
              silent = true;
              desc = "Save current session";
            };
          }
          {
            mode = "n";
            key = "<leader>Sr";
            action = "<cmd>lua _G.restore_session_with_notify()<CR>";
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
