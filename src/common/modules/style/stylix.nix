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

  settings = {
    fonts = null;
    cursor = null;
    wallpaper = {
      # Default will use self.file "wallpaper.jpg"
    };
  };

  on =
    let
      stylixConfig =
        config:
        let
          theme = config.nx.preferences.theme;
          fonts = if self.settings.fonts != null then self.settings.fonts else theme.fonts;
          cursor = if self.settings.cursor != null then self.settings.cursor else theme.cursor;

          themeYaml = ''
            system: "base16"
            name: "NX Theme"
            author: "NX User"
            variant: "${theme.variant}"
            palette:
              base00: "${theme.colors.main.backgrounds.primary.html}"
              base01: "${theme.colors.main.backgrounds.secondary.html}"
              base02: "${theme.colors.main.backgrounds.tertiary.html}"
              base03: "${theme.colors.main.foregrounds.subtle.html}"
              base04: "${theme.colors.main.foregrounds.secondary.html}"
              base05: "${theme.colors.main.foregrounds.primary.html}"
              base06: "${theme.colors.main.foregrounds.emphasized.html}"
              base07: "${theme.colors.main.foregrounds.strong.html}"
              base08: "${theme.colors.main.base.red.html}"
              base09: "${theme.colors.main.base.orange.html}"
              base0A: "${theme.colors.main.base.yellow.html}"
              base0B: "${theme.colors.main.base.green.html}"
              base0C: "${theme.colors.main.base.cyan.html}"
              base0D: "${theme.colors.main.base.blue.html}"
              base0E: "${theme.colors.main.base.purple.html}"
              base0F: "${theme.colors.main.base.pink.html}"
          '';

          customSchemeFile = builtins.toFile "nx-theme.yaml" themeYaml;

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

          fontPackages = [
            (getPackage fonts.serif)
            (getPackage fonts.sansSerif)
            (getPackage fonts.monospace)
            (getPackage fonts.emoji)
          ]
          ++ lib.optionals (cursor != null) [
            (getPackage cursor.style)
          ];

          stylixAttrs = {
            enable = true;

            base16Scheme = customSchemeFile;

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

            polarity = theme.variant;

            cursor = lib.mkIf (cursor != null) {
              package = getPackage cursor.style;
              name = lib.last (lib.splitString "/" cursor.style);
              size = cursor.size;
            };

            fonts = {
              serif = {
                package = getPackage fonts.serif;
                name = lib.last (
                  lib.splitString "/" (if builtins.isString fonts.serif then fonts.serif else fonts.serif.path)
                );
              };
              sansSerif = {
                package = getPackage fonts.sansSerif;
                name = lib.last (
                  lib.splitString "/" (
                    if builtins.isString fonts.sansSerif then fonts.sansSerif else fonts.sansSerif.path
                  )
                );
              };
              monospace = {
                package = getPackage fonts.monospace;
                name = lib.last (
                  lib.splitString "/" (
                    if builtins.isString fonts.monospace then fonts.monospace else fonts.monospace.path
                  )
                );
              };
              emoji = {
                package = getPackage fonts.emoji;
                name = lib.last (
                  lib.splitString "/" (if builtins.isString fonts.emoji then fonts.emoji else fonts.emoji.path)
                );
              };
            };

            autoEnable = true;
          };
        in
        {
          inherit fontPackages stylixAttrs;
        };
    in
    {
      system =
        config:
        let
          shared = stylixConfig config;
        in
        {
          environment.systemPackages = shared.fontPackages;
          stylix = shared.stylixAttrs;
        };

      standalone =
        config:
        let
          shared = stylixConfig config;
        in
        {
          home.packages = shared.fontPackages;
          stylix = shared.stylixAttrs // {
            targets = {
              kde.enable = false;
              gnome.enable = false;
            };
          };
        };
    };
}
