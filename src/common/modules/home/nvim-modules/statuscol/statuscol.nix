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
  name = "statuscol";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraConfigLua = ''
          _G.nx_modules = _G.nx_modules or {}
          _G.nx_modules["30-statuscol"] = function()
            _G.buffer_has_folds = function()
              if vim.wo.foldmethod == 'manual' then
                return vim.fn.foldlevel(1) > 0
              else
                return vim.wo.foldmethod ~= 'manual' and vim.wo.foldmethod ~= ""
              end
            end

            _G.line_has_folds = function()
              local line = vim.fn.line('.')
              return vim.fn.foldlevel(line) > 0 or vim.fn.foldclosed(line) ~= -1
            end

            vim.api.nvim_set_hl(0, 'StatusColSeparator', { fg = '${self.theme.colors.separators.ultraDark.html}' })
          end
        '';

        plugins.statuscol = {
          enable = true;
          settings = {
            setopt = true;
            relculright = true;
            segments = [
              {
                text = [ " " ];
                click = "v:lua.ScFa";
                condition = [
                  {
                    __raw = "function() local ok, has_buf_folds = pcall(function() return _G.buffer_has_folds() end); return ok and has_buf_folds or false end";
                  }
                ];
              }
              {
                text = [ " " ];
                condition = [
                  {
                    __raw = "function() local ok, has_buf_folds = pcall(function() return _G.buffer_has_folds() end); return ok and not has_buf_folds or false end";
                  }
                ];
              }
              {
                text = [ { __raw = "require('statuscol.builtin').foldfunc"; } ];
                click = "v:lua.ScFa";
                condition = [
                  {
                    __raw = "function() local ok, has_buf_folds = pcall(function() return _G.buffer_has_folds() end); local ok2, has_line_folds = pcall(function() return _G.line_has_folds() end); return (ok and has_buf_folds) and (ok2 and has_line_folds) or false end";
                  }
                ];
              }
              {
                text = [ "  " ];
                click = "v:lua.ScFa";
                condition = [
                  {
                    __raw = "function() local ok, has_buf_folds = pcall(function() return _G.buffer_has_folds() end); return ok and has_buf_folds or false end";
                  }
                ];
              }
              {
                sign = {
                  namespace = [ "dap" ];
                  name = [ "Dap.*" ];
                  maxwidth = 1;
                  auto = true;
                };
                click = "v:lua.ScSa";
              }
              {
                sign = {
                  text = [ "" ];
                  maxwidth = 1;
                  auto = true;
                };
                click = "v:lua.ScSa";
              }
              {
                sign = {
                  text = [ "" ];
                  maxwidth = 1;
                  auto = true;
                };
                click = "v:lua.ScSa";
              }
              {
                sign = {
                  text = [ "" ];
                  maxwidth = 1;
                  auto = true;
                };
                click = "v:lua.ScSa";
              }
              {
                sign = {
                  text = [ "󰌵" ];
                  maxwidth = 1;
                  auto = true;
                };
                click = "v:lua.ScSa";
              }
              {
                sign = {
                  namespace = [ ".*" ];
                  name = [ ".*" ];
                  text = [ ".*" ];
                  maxwidth = 3;
                  auto = true;
                };
                click = "v:lua.ScSa";
              }
              {
                text = [ { __raw = "require('statuscol.builtin').lnumfunc"; } ];
                click = "v:lua.ScLa";
              }
              {
                text = [ " " ];
                condition = [
                  {
                    __raw = "function() local ok, cache = pcall(require, 'gitsigns.cache'); if not ok then return false end; local buf_cache = cache.cache[vim.api.nvim_get_current_buf()]; if not buf_cache then return false end; local unstaged = buf_cache.hunks and #buf_cache.hunks or 0; local staged = buf_cache.hunks_staged and #buf_cache.hunks_staged or 0; return unstaged > 0 or staged > 0 end";
                  }
                ];
              }
              {
                sign = {
                  namespace = [ "gitsigns" ];
                  name = [ "GitSigns.*" ];
                  maxwidth = 1;
                  auto = true;
                };
                click = "v:lua.ScLa";
              }
              {
                text = [ " " ];
                click = "v:lua.ScLa";
                condition = [
                  {
                    __raw = "function() local ok, cache = pcall(require, 'gitsigns.cache'); if not ok then return false end; local buf_cache = cache.cache[vim.api.nvim_get_current_buf()]; if not buf_cache then return false end; local unstaged = buf_cache.hunks and #buf_cache.hunks or 0; local staged = buf_cache.hunks_staged and #buf_cache.hunks_staged or 0; return not (unstaged > 0 or staged > 0) end";
                  }
                ];
              }
              {
                text = [ "│" ];
                hl = "StatusColSeparator";
              }
              {
                text = [ " " ];
              }
            ];
          };
        };

        opts = {
          signcolumn = lib.mkForce "no";
        };
      };
    };
}
