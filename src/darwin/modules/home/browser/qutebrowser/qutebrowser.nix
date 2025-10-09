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
  name = "qutebrowser";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
    common = {
      browser = {
        qutebrowser-config = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/qutebrowser.brew".text = ''
        cask 'qutebrowser'
      '';
    };
}
