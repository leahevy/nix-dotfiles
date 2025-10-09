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
  name = "keyboard-cowboy";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/keyboard-cowboy.brew".text = ''
        cask 'keyboard-cowboy'
      '';
    };
}
