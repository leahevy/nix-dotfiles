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
      monospace = "nerd-fonts.fira-code/FiraCode Nerd Font";
      emoji = "noto-fonts-emoji-blob-bin/Blobmoji";
    };
    cursor = {
      style = "rose-pine-cursor/BreezeX-RosePine-Linux";
      size = 40;
    };
    wallpaper = {
      # Default will use self.file "wallpaper.jpg"
    };
  };

  configuration =
    context@{
      config,
      options,
      ...
    }:
    let
      getPackage =
        fontPath:
        let
          packageName = lib.head (lib.splitString "/" fontPath);
          packageParts = lib.splitString "." packageName;
        in
        if lib.length packageParts > 1 then
          lib.getAttrFromPath packageParts pkgs
        else
          lib.getAttr packageName pkgs;
    in
    {
      environment.systemPackages = [
        (getPackage self.settings.fonts.serif)
        (getPackage self.settings.fonts.sansSerif)
        (getPackage self.settings.fonts.monospace)
        (getPackage self.settings.fonts.emoji)
      ]
      ++ lib.optionals (self.settings.cursor != null) [
        (getPackage self.settings.cursor.style)
      ];

      stylix = {
        enable = true;

        base16Scheme = "${pkgs.base16-schemes}/share/themes/${self.settings.themeName}.yaml";

        image =
          if (self.settings.wallpaper.config or null) != null then
            self.config.filesPath self.settings.wallpaper.config
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
            self.file "wallpaper.jpg";

        polarity = self.settings.polarity;

        cursor = lib.mkIf (self.settings.cursor != null) {
          package = getPackage self.settings.cursor.style;
          name = lib.last (lib.splitString "/" self.settings.cursor.style);
          size = self.settings.cursor.size;
        };

        fonts = {
          serif = {
            package = getPackage self.settings.fonts.serif;
            name = lib.last (lib.splitString "/" self.settings.fonts.serif);
          };
          sansSerif = {
            package = getPackage self.settings.fonts.sansSerif;
            name = lib.last (lib.splitString "/" self.settings.fonts.sansSerif);
          };
          monospace = {
            package = getPackage self.settings.fonts.monospace;
            name = lib.last (lib.splitString "/" self.settings.fonts.monospace);
          };
          emoji = {
            package = getPackage self.settings.fonts.emoji;
            name = lib.last (lib.splitString "/" self.settings.fonts.emoji);
          };
        };

        autoEnable = true;
      };
    };
}
