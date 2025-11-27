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
  name = "numbertoggle";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        plugins.numbertoggle = {
          enable = true;
        };

        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}

          _G.nx_modules["42-numbertoggle-fix"] = function()
            vim.api.nvim_create_autocmd({"VimEnter"}, {
              callback = function()
                vim.defer_fn(function()
                  local mode = vim.fn.mode()
                  if mode == 'n' or mode == 'no' then
                    vim.opt_local.relativenumber = true
                    vim.opt_local.number = true
                  elseif mode == 'i' or mode == 'ic' or mode == 'ix' then
                    vim.opt_local.relativenumber = false
                    vim.opt_local.number = true
                  end
                end, 50)
              end,
            })
          end
        '';
      };
    };
}
