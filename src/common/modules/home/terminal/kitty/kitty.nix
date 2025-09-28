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
  name = "kitty";

  defaults = {
    setEnv = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.kitty = {
        enable = true;
        settings = { };
      };

      home.sessionVariables = lib.mkIf self.settings.setEnv {
        TERMINAL = "kitty";
      };
    };
}
