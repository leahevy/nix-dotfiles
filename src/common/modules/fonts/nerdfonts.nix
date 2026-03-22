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

  on = {
    home = config: {
      home.packages = with pkgs; [
        nerd-fonts.dejavu-sans-mono
        nerd-fonts.ubuntu
      ];
    };
  };
}
