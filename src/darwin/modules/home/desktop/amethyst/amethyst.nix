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
  name = "amethyst";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
      desktop = {
        keyboard-cowboy = true;
      };
    };
  };

  assertions = [
    {
      assertion = !self.isModuleEnabled "desktop.yabai";
      message = "Yabai and amethyst are mutually exclusive!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/amethyst.brew".text = ''
        cask 'amethyst'
      '';
    };
}
