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
  name = "ghostty";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
    common = {
      terminal = {
        ghostty-config = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/ghostty.brew".text = ''
        cask 'ghostty'
      '';
    };
}
