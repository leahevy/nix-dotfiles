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

  assertions = [
    {
      assertion = !self.isModuleEnabled "desktop.yabai";
      message = "Keyboard-Cowboy and yabai are mutually exclusive!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/keyboard-cowboy.brew".text = ''
        cask 'keyboard-cowboy'
      '';
    };
}
