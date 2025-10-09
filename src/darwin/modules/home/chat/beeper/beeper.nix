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
  name = "beeper";

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
      home.file.".config/homebrew/beeper.brew".text = ''
        cask 'beeper'
      '';
    };
}
