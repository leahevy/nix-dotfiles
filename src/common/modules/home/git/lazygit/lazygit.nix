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
  name = "lazygit";

  configuration =
    context@{ config, options, ... }:
    {
      programs.lazygit = {
        enable = true;
      };

      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          lazygit-nvim
        ];
      };
    };
}
