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

  group = "style";
  input = "common";
  namespace = "home";

  settings = {
    fonts = self.theme.fonts;
    cursor = self.theme.cursor;
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
      themeYaml = ''
        system: "base16"
        name: "NX Theme"
        author: "NX User"
        variant: "${self.theme.variant}"
        palette:
          base00: "${self.theme.colors.main.backgrounds.primary.html}"
          base01: "${self.theme.colors.main.backgrounds.secondary.html}"
          base02: "${self.theme.colors.main.backgrounds.tertiary.html}"
          base03: "${self.theme.colors.main.foregrounds.subtle.html}"
          base04: "${self.theme.colors.main.foregrounds.secondary.html}"
          base05: "${self.theme.colors.main.foregrounds.primary.html}"
          base06: "${self.theme.colors.main.foregrounds.emphasized.html}"
          base07: "${self.theme.colors.main.foregrounds.strong.html}"
          base08: "${self.theme.colors.main.base.red.html}"
          base09: "${self.theme.colors.main.base.orange.html}"
          base0A: "${self.theme.colors.main.base.yellow.html}"
          base0B: "${self.theme.colors.main.base.green.html}"
          base0C: "${self.theme.colors.main.base.cyan.html}"
          base0D: "${self.theme.colors.main.base.blue.html}"
          base0E: "${self.theme.colors.main.base.purple.html}"
          base0F: "${self.theme.colors.main.base.pink.html}"
      '';

      customSchemePackage = pkgs.writeTextDir "share/themes/nx-theme.yaml" themeYaml;

      getPackage =
        fontConfig:
        let
          fontPath = if builtins.isString fontConfig then fontConfig else fontConfig.path;
          useUnstable = if builtins.isString fontConfig then false else (fontConfig.useUnstable or false);
          packageName = lib.head (lib.splitString "/" fontPath);
          packageParts = lib.splitString "." packageName;
          pkgSet = if useUnstable then pkgs-unstable else pkgs;
        in
        if lib.length packageParts > 1 then
          lib.getAttrFromPath packageParts pkgSet
        else
          lib.getAttr packageName pkgSet;
    in
    lib.mkIf self.user.isStandalone {
      home.packages = [
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

        base16Scheme = "${customSchemePackage}/share/themes/nx-theme.yaml";

        targets = {
          kde.enable = false;
          gnome.enable = false;
        };

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

        polarity = self.theme.variant;

        cursor = lib.mkIf (self.settings.cursor != null) {
          package = getPackage self.settings.cursor.style;
          name = lib.last (lib.splitString "/" self.settings.cursor.style);
          size = self.settings.cursor.size;
        };

        fonts = {
          serif = {
            package = getPackage self.settings.fonts.serif;
            name = lib.last (
              lib.splitString "/" (
                if builtins.isString self.settings.fonts.serif then
                  self.settings.fonts.serif
                else
                  self.settings.fonts.serif.path
              )
            );
          };
          sansSerif = {
            package = getPackage self.settings.fonts.sansSerif;
            name = lib.last (
              lib.splitString "/" (
                if builtins.isString self.settings.fonts.sansSerif then
                  self.settings.fonts.sansSerif
                else
                  self.settings.fonts.sansSerif.path
              )
            );
          };
          monospace = {
            package = getPackage self.settings.fonts.monospace;
            name = lib.last (
              lib.splitString "/" (
                if builtins.isString self.settings.fonts.monospace then
                  self.settings.fonts.monospace
                else
                  self.settings.fonts.monospace.path
              )
            );
          };
          emoji = {
            package = getPackage self.settings.fonts.emoji;
            name = lib.last (
              lib.splitString "/" (
                if builtins.isString self.settings.fonts.emoji then
                  self.settings.fonts.emoji
                else
                  self.settings.fonts.emoji.path
              )
            );
          };
        };

        autoEnable = true;
      };
    };
}
