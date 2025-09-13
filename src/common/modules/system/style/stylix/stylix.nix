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
  name = "stylix";

  defaults = {
    themeName = "atelier-seaside";
    polarity = "dark";
    fonts = {
      serif = "dejavu_fonts/DejaVu Serif";
      sansSerif = "dejavu_fonts/DejaVu Sans";
      monospace = "dejavu_fonts/DejaVu Sans Mono";
      emoji = "noto-fonts-emoji/Noto Color Emoji";
    };
    wallpaper = {
      # Default will use self.file "wallpaper.png"
    };
  };

  configuration =
    context@{
      config,
      options,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        (lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.serif)) pkgs)
        (lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.sansSerif)) pkgs)
        (lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.monospace)) pkgs)
        (lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.emoji)) pkgs)
      ];

      stylix = {
        enable = true;

        base16Scheme = "${pkgs.base16-schemes}/share/themes/${self.settings.themeName}.yaml";

        image =
          if (self.settings.wallpaper.config or null) != null then
            helpers.filesPathFromInput "config" self.settings.wallpaper.config
          else if
            (self.settings.wallpaper.url or null) != null && (self.settings.wallpaper.url.url or null) != null
          then
            pkgs.fetchurl {
              url = self.settings.wallpaper.url.url;
              hash = self.settings.wallpaper.url.hash;
            }
          else if (self.settings.wallpaper.local or null) != null then
            self.settings.wallpaper.local
          else
            self.file "wallpaper.png";

        polarity = self.settings.polarity;

        fonts = {
          serif = {
            package = lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.serif)) pkgs;
            name = lib.last (lib.splitString "/" self.settings.fonts.serif);
          };
          sansSerif = {
            package = lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.sansSerif)) pkgs;
            name = lib.last (lib.splitString "/" self.settings.fonts.sansSerif);
          };
          monospace = {
            package = lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.monospace)) pkgs;
            name = lib.last (lib.splitString "/" self.settings.fonts.monospace);
          };
          emoji = {
            package = lib.getAttr (lib.head (lib.splitString "/" self.settings.fonts.emoji)) pkgs;
            name = lib.last (lib.splitString "/" self.settings.fonts.emoji);
          };
        };

        autoEnable = true;
      };
    };
}
