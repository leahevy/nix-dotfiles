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
  name = "japanese";

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
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        source-han-sans
        source-han-serif
      ];
    };
  };
}
