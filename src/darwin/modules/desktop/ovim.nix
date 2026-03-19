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
  name = "ovim";

  group = "desktop";
  input = "darwin";
  namespace = "home";

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
      home.file.".config/homebrew/ovim.tap".text = ''
        tap 'tonisives/tap'
      '';

      home.file.".config/homebrew/ovim.brew".text = ''
        cask 'ovim'
      '';
    };
}
