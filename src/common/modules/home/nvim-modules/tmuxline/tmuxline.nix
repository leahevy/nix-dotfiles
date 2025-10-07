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
  name = "tmuxline";

  configuration =
    context@{ config, options, ... }:
    {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          tmuxline-vim
        ];
      };
    };
}
