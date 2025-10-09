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
  name = "keepassxc";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
    common = {
      passwords = {
        keepassxc = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/keepassxc.brew".text = ''
        cask 'keepassxc'
      '';
    };
}
