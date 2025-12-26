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

  group = "fonts";
  input = "common";
  namespace = "home";

  settings = {
    withUnfreeFonts = false;
  };

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
          noto-fonts-color-emoji
          unifont
        ])
        ++ lib.optionals self.settings.withUnfreeFonts (
          with pkgs;
          [
            corefonts
            symbola
          ]
        );
    };
}
