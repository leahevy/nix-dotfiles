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

  group = "browser";
  input = "darwin";
  namespace = "home";

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
