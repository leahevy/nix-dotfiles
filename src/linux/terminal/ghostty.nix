args@{
  lib,
  pkgs,
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

  module = {
    linux.enabled =
      config:
      let
        ghosttyBin =
          if self.user.isStandalone then
            pkgs.writeShellScriptBin "ghostty" ''exec /usr/bin/ghostty "$@"''
          else
            pkgs.ghostty;
      in
      {
        nx.preferences.desktop.programs.additionalTerminal.package = lib.mkDefault ghosttyBin;
        nx.preferences.desktop.programs.terminal.package = lib.mkForce ghosttyBin;
        nx.apt.packages = [ "ghostty" ];
      };

    linux.home =
      config:
      let
        ghosttyBin =
          if self.user.isStandalone then
            pkgs.writeShellScriptBin "ghostty" ''exec /usr/bin/ghostty "$@"''
          else
            pkgs.ghostty;
      in
      {
        programs.ghostty.package = lib.mkForce ghosttyBin;
      };
  };
}
