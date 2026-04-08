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

  on = {
    linux.enabled = config: {
      nx.preferences.desktop.programs.additionalTerminal.package = lib.mkDefault pkgs.ghostty;
      nx.preferences.desktop.programs.terminal.package = lib.mkForce pkgs.ghostty;
    };

    linux.home = config: {
      programs.ghostty.package = lib.mkForce pkgs.ghostty;
    };
  };
}
