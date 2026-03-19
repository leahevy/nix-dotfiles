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

  group = "chat";
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
      home.file.".config/homebrew/beeper.brew".text = ''
        cask 'beeper'
      '';
    };
}
