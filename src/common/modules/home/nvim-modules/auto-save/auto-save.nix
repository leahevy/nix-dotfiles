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
  name = "auto-save";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    enable = true;
    debounceDelay = 5000;
    onlyInHomeDirectories = true;
    showNotifications = true;
    withData = false;
    dataPath = "/data";

    excludedFiletypes = [
      "help"
      "dashboard"
      "toggleterm"
      "NvimTree"
      "telescope"
      "lspinfo"
      "checkhealth"
      "man"
      "qf"
      "gitcommit"
      "gitrebase"
      "fugitive"
      "startify"
      "notify"
      "yazi"
      "trouble"
      "alpha"
      "netrw"
      "Codewindow"
      "dapui_scopes"
      "dapui_breakpoints"
      "dapui_stacks"
      "dapui_watches"
      "dapui-repl"
      "dapui_console"
      "dap-repl"
      "OverseerList"
      "neotest-output-panel"
      "neotest-summary"
      ""
    ];

    excludedBufferTypes = [
      "terminal"
      "nofile"
      "nowrite"
      "prompt"
      "help"
      "quickfix"
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.auto-save = {
          enable = self.settings.enable;
          settings = {
            enabled = true;
            trigger_events = {
              immediate_save = [
                "BufLeave"
                "BufDelete"
                "BufWipeout"
                "BufFilePre"
                "BufFilePost"
                "BufWinLeave"
                "BufUnload"
                "BufHidden"
                "FocusLost"
                "TabLeave"
                "WinLeave"
                "QuitPre"
                "VimSuspend"
                "CmdwinEnter"
                "InsertLeave"
                "TextChanged"
                "FileReadPost"
                "FilterReadPost"
                "StdinReadPost"
              ];
              defer_save = [
                "TextChangedI"
              ];
              cancel_deferred_save = [ "InsertEnter" ];
            };
            write_all_buffers = false;
            debounce_delay = self.settings.debounceDelay;
            noautocmd = false;
            condition.__raw = ''
              function(buf)
                local bufname = vim.api.nvim_buf_get_name(buf)
                local filetype = vim.bo[buf].filetype
                local buftype = vim.bo[buf].buftype

                if not vim.bo[buf].modified then
                  return false
                end

                if bufname == "" or vim.fn.filereadable(bufname) ~= 1 then
                  return false
                end

                if vim.bo[buf].readonly then
                  return false
                end

                ${
                  if self.settings.onlyInHomeDirectories then
                    ''
                      local home_pattern = ${if self.isLinux then ''"^/home/"'' else ''"^/Users/"''}
                      local in_home = bufname:match(home_pattern)
                      ${lib.optionalString (!self.user.isStandalone && self.settings.withData) ''
                        local data_pattern = "^${self.settings.dataPath}/"
                        local in_data = bufname:match(data_pattern)
                      ''}
                      if not in_home${
                        lib.optionalString (!self.user.isStandalone && self.settings.withData) " and not in_data"
                      } then
                        return false
                      end
                    ''
                  else
                    ""
                }

                local excluded_buftypes = {${
                  lib.concatMapStringsSep ", " (bt: ''"${bt}"'') self.settings.excludedBufferTypes
                }}
                for _, excluded_buftype in ipairs(excluded_buftypes) do
                  if buftype == excluded_buftype then
                    return false
                  end
                end

                local excluded_filetypes = {${
                  lib.concatMapStringsSep ", " (ft: ''"${ft}"'') self.settings.excludedFiletypes
                }}
                for _, excluded_filetype in ipairs(excluded_filetypes) do
                  if filetype == excluded_filetype then
                    return false
                  end
                end

                return true
              end
            '';
          };
        };

        plugins.which-key.settings.spec = lib.mkIf (self.isModuleEnabled "nvim-modules.which-key") [
          {
            __unkeyed-1 = "<leader>A";
            desc = "Toggle auto-save";
            icon = "🔄";
          }
        ];

        keymaps = [
          {
            mode = "n";
            key = "<leader>A";
            action.__raw = ''
              function()
                local old_state = _G.autosave_enabled
                vim.cmd("ASToggle")
                local status = old_state and "disabled" or "enabled"
                vim.notify("Auto-save " .. status, vim.log.levels.INFO, {
                  title = "Auto Save"
                })
              end
            '';
            options = {
              desc = "Toggle auto-save";
              silent = true;
            };
          }
        ];

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["70-auto-save"] = function()
            _G.autosave_in_progress = false
            _G.autosave_enabled = true

            vim.api.nvim_create_autocmd("User", {
              pattern = "AutoSaveWritePre",
              callback = function()
                _G.autosave_in_progress = true
              end,
            })

            vim.api.nvim_create_autocmd("User", {
              pattern = "AutoSaveWritePost",
              callback = function()
                _G.autosave_in_progress = false
              end,
            })

            vim.api.nvim_create_autocmd("User", {
              pattern = "AutoSaveEnable",
              callback = function()
                _G.autosave_enabled = true
              end,
            })

            vim.api.nvim_create_autocmd("User", {
              pattern = "AutoSaveDisable",
              callback = function()
                _G.autosave_enabled = false
              end,
            })
          end
        '';
      };

    };
}
