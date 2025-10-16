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
  name = "highlight-dead-chars";
  description = "Highlights whitespace and non-text characters in Neovim";

  group = "nvim-modules";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nvim-init/50-highlight-dead-chars.lua".text = ''
        vim.api.nvim_set_hl(0, "Whitespace", { fg = "#404040" })
        vim.api.nvim_set_hl(0, "NonText", { fg = "#404040" })
      '';
    };
}
