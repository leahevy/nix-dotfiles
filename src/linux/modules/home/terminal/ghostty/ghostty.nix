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

  init =
    context@{ config, options, ... }:
    lib.mkIf self.isEnabled {
      nx.preferences.desktop.programs.terminal.package = lib.mkDefault pkgs.ghostty;
    };

  configuration =
    context@{ config, options, ... }:
    {
      programs.ghostty.package = lib.mkForce pkgs.ghostty;
    };
}
