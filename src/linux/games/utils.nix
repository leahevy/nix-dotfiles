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
  name = "utils";

  group = "games";
  input = "linux";

  module = {
    linux.home = config: {
      home.packages = with pkgs; [
        jstest-gtk
        evtest
        linuxConsoleTools
        SDL2
      ];
    };
  };
}
