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
  name = "nerdfonts";

  group = "fonts";
  input = "common";

  submodules = {
    common = {
      fonts = {
        fontconfig = true;
      };
    };
  };

  module = {
    home = config: {
      home.packages = with pkgs; [
        nerd-fonts.dejavu-sans-mono
        nerd-fonts.ubuntu
      ];
    };
  };
}
