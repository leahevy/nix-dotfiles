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

  group = "nvim-modules";
  input = "common";

  module = {
    home = config: {
      programs.nixvim = {
        extraPlugins = with pkgs.vimPlugins; [
          tmuxline-vim
        ];
      };
    };
  };
}
