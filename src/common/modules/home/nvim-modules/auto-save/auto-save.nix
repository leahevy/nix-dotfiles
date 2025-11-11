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
    debounceDelay = 500;
    onlyInHomeDirectories = true;
    showNotifications = true;

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
                "FocusLost"
                "QuitPre"
                "VimSuspend"
              ];
              defer_save = [
                "InsertLeave"
                "TextChanged"
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
                      if not bufname:match(home_pattern) then
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
      };

      home.file.".config/nvim-init/70-auto-save.lua".text = ''
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
      '';

      programs.nixvim.plugins.which-key.settings.spec =
        lib.mkIf (self.isModuleEnabled "nvim-modules.which-key")
          [
            {
              __unkeyed-1 = "<leader>A";
              desc = "Toggle auto-save";
              icon = "🔄";
            }
          ];
    };
}
