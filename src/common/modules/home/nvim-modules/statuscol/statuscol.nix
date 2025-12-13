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
        plugins.statuscol = {
          enable = true;
          settings = {
            setopt = true;
            relculright = true;
            segments = [
              {
                text = [ { __raw = "require('statuscol.builtin').foldfunc"; } ];
                click = "v:lua.ScFa";
                condition = [
                  {
                    __raw = "function() return vim.fn.foldlevel(vim.fn.line('.')) > 0 or vim.fn.foldclosed(vim.fn.line('.')) ~= -1 end";
                  }
                ];
              }
              {
                text = [ " " ];
                click = "v:lua.ScFa";
                condition = [
                  {
                    __raw = "function() return vim.fn.foldlevel(vim.fn.line('.')) > 0 or vim.fn.foldclosed(vim.fn.line('.')) ~= -1 end";
                  }
                ];
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
