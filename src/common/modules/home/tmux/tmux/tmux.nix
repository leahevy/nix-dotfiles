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
  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        tmux
        tmuxinator
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".tmux"
          ".config/tmux"
        ];
      };
    };
}
