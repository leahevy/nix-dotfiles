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
  meta = {
    name = "auto-create-dirs";
    description = "Automatically creates parent directories when saving files in Neovim";
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/50-auto-create-dirs.lua".text = ''
        vim.api.nvim_create_autocmd("BufWritePre", {
          pattern = "*",
          callback = function()
            local dir = vim.fn.expand("<afile>:p:h")
            if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
              if vim.v.cmdbang == "!" 
                 or vim.fn.input(string.format("Create directory %s? [y/N]: ", dir)):lower():match("^y") then
                vim.fn.mkdir(dir, "p")
              end
            end
          end,
        })
      '';
    };
}
