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

  group = "git";
  input = "common";
  namespace = "home";

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
