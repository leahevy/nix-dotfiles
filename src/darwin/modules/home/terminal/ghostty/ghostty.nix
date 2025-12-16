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

  group = "terminal";
  input = "darwin";
  namespace = "home";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
    common = {
      terminal = {
        ghostty-config = {
          setEnv = true;
        };
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
