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
    pureBlackBackground = true;
    pureWhiteForeground = true;
    fonts = {
      serif = {
        path = "dejavu_fonts/DejaVu Serif";
        useUnstable = false;
      };
      sansSerif = {
        path = "dejavu_fonts/DejaVu Sans";
        useUnstable = false;
      };
      monospace = {
        path = "nerd-fonts.fira-code/FiraCode Nerd Font";
        useUnstable = false;
      };
      emoji = {
        path = "noto-fonts-emoji-blob-bin/Blobmoji";
        useUnstable = false;
      };
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
      customSchemePackage = pkgs.runCommand "custom-${self.settings.themeName}-schemes" { } ''
        mkdir -p $out/share/themes
        cp ${pkgs.base16-schemes}/share/themes/${self.settings.themeName}.yaml temp.yaml
        ${pkgs.yq-go}/bin/yq eval '. ${lib.optionalString self.settings.pureBlackBackground "| .palette.base00 = \"#000000\" | .palette.base01 = \"#000000\""}${lib.optionalString self.settings.pureWhiteForeground "| .palette.base05 = \"#eeeeee\" | .palette.base06 = \"#cdcdcd\" | .palette.base07 = \"#ffffff\""}' temp.yaml > $out/share/themes/${self.settings.themeName}.yaml
      '';

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

        base16Scheme =
          if self.settings.pureBlackBackground || self.settings.pureWhiteForeground then
            "${customSchemePackage}/share/themes/${self.settings.themeName}.yaml"
          else
            "${pkgs.base16-schemes}/share/themes/${self.settings.themeName}.yaml";

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
