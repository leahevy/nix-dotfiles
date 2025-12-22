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
  name = "alacritty";
  #description = "";

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
        alacritty-config = {
          setEnv = false;
        };
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/alacritty.brew".text = ''
        cask 'alacritty'
      '';
    };
}
