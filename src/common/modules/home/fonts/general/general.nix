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
  name = "general";

  submodules = {
    common = {
      fonts = {
        fontconfig = true;
      };
    };
  };

  unfree = [
    "corefonts"
    "symbola"
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.packages =
        (with pkgs; [
          dejavu_fonts
          liberation_ttf
          inter
          roboto
          open-sans
          noto-fonts-emoji
          unifont
        ])
        ++ (with pkgs-unstable; [
          corefonts
          symbola
        ]);
    };
}
