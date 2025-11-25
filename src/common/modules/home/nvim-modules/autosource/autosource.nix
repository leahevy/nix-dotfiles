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
  name = "autosource";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  settings = {
    promptForChangedFile = true;
    promptForNewFile = true;
    approveOnSave = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.autosource = {
          enable = true;
          autoLoad = true;
          settings = {
            prompt_for_changed_file = if self.settings.promptForChangedFile then 1 else 0;
            prompt_for_new_file = if self.settings.promptForNewFile then 1 else 0;
          };
        };

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["05-autosource-config"] = function()
            vim.g.autosource_approve_on_save = ${if self.settings.approveOnSave then "1" else "0"}

            vim.g.autosource_disable_autocmd = 1

            local autosource_ready = false

            local augroup = vim.api.nvim_create_augroup('custom_autosource', { clear = true })

            vim.api.nvim_create_autocmd({'BufReadPost', 'BufNewFile'}, {
              group = augroup,
              callback = function(event)
                if not autosource_ready or vim.g.SessionLoad then
                  return
                end

                local filepath = event.file
                if filepath == "" or not vim.fn.filereadable(filepath) then
                  return
                end

                pcall(vim.fn.AutoSource, vim.fn.expand('%:p:h'))
              end
            })

            vim.api.nvim_create_autocmd('VimEnter', {
              once = true,
              callback = function()
                vim.defer_fn(function()
                  autosource_ready = true
                  if vim.fn.expand('%') ~= "" then
                    pcall(vim.fn.AutoSource, vim.fn.expand('%:p:h'))
                  end
                end, 500)
              end
            })
          end
        '';
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".autosource_hashes"
        ];
      };
    };
}
