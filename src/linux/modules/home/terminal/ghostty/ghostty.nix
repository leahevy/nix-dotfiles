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
  input = "linux";
  namespace = "home";

  submodules = {
    common = {
      terminal = {
        ghostty-config = {
          setEnv = self.settings.setEnv;
        };
      };
    };
  };

  settings = {
    setEnv = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.ghostty.package = lib.mkForce pkgs.ghostty;
    };
}
