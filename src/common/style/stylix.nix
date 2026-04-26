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

  options =
    let
      fontType = lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = "Font path in format: package/FontName";
          };
          useUnstable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to use unstable package";
          };
        };
      };
      resolvedFontType = lib.types.submodule {
        options = {
          package = lib.mkOption {
            type = lib.types.package;
            description = "Package of the font";
          };
          name = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Name of the font";
          };
        };
      };
    in
    {
      fonts = lib.mkOption {
        type = lib.types.submodule {
          options = {
            serif = lib.mkOption {
              type = lib.types.nullOr fontType;
              default = null;
            };
            sansSerif = lib.mkOption {
              type = lib.types.nullOr fontType;
              default = null;
            };
            monospace = lib.mkOption {
              type = lib.types.nullOr fontType;
              default = null;
            };
            emoji = lib.mkOption {
              type = lib.types.nullOr fontType;
              default = null;
            };
          };
        };
        default = { };
        description = "Font settings";
      };
      resolvedFonts = lib.mkOption {
        type = lib.types.submodule {
          options = {
            serif = lib.mkOption {
              type = resolvedFontType;
            };
            sansSerif = lib.mkOption {
              type = resolvedFontType;
            };
            monospace = lib.mkOption {
              type = resolvedFontType;
            };
            emoji = lib.mkOption {
              type = resolvedFontType;
            };
          };
        };
        default = { };
        description = "Resolved font settings";
      };
      cursor = lib.mkOption {
        type = lib.types.submodule {
          options = {
            style = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Cursor style (format: package/CursorName)";
            };
            size = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "Cursor size";
            };
          };
        };
        default = { };
        description = "Cursor settings";
      };
      resolvedCursor = lib.mkOption {
        type = lib.types.submodule {
          options = {
            package = lib.mkOption {
              type = lib.types.package;
              description = "Package of the cursor";
            };
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the cursor";
            };
            size = lib.mkOption {
              type = lib.types.int;
              description = "Cursor size";
            };
          };
        };
        default = { };
        description = "Resolved cursor settings";
      };

      wallpaper = lib.mkOption {
        type = lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.submodule {
                options = {
                  configPath = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Path to wallpaper from nxconfig root";
                  };
                  url = lib.mkOption {
                    type = lib.types.nullOr (
                      lib.types.submodule {
                        options = {
                          url = lib.mkOption {
                            type = lib.types.str;
                            default = "";
                            description = "URL of the wallpaper";
                          };
                          hash = lib.mkOption {
                            type = lib.types.str;
                            default = "";
                            description = "Hash of the wallpaper";
                          };
                        };
                      }
                    );
                    default = null;
                    description = "URL to fetch wallpaper";
                  };
                  localPath = lib.mkOption {
                    type = lib.types.nullOr lib.types.path;
                    default = null;
                    description = "Path to a wallpaper";
                  };
                };
              };
              default = { };
              description = "Different configuration ways to set the wallpaper";
            };
            extension = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The extension of the wallpaper file. If null: derived from the file name (but will error if source is a /nix/store path).";
            };
          };
        };
        default = { };
        description = "Wallpaper settings";
      };
      resolvedWallpaper = lib.mkOption {
        type = lib.types.submodule {
          options = {
            source = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = "Resolved wallpaper";
            };
            extension = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Resolved wallpaper extension or null if it should be derived from file name";
            };
          };
        };
      };
    };

  module =
    let
      stylixConfig =
        config:
        let
          opts = config.nx.common.style.stylix;
          theme = config.nx.preferences.theme;
          fonts =
            if
              opts.fonts != null
              && opts.fonts.serif != null
              && opts.fonts.serif.path != null
              && opts.fonts.sansSerif != null
              && opts.fonts.sansSerif.path != null
              && opts.fonts.monospace != null
              && opts.fonts.monospace.path != null
              && opts.fonts.emoji != null
              && opts.fonts.emoji.path != null
            then
              opts.fonts
            else
              theme.fonts;
          cursor =
            if opts.cursor != null && opts.cursor.size != null && opts.cursor.style != null then
              opts.cursor
            else
              theme.cursor;

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
              let
                wallpaper = config.nx.common.style.stylix.wallpaper.source;
                isWidescreen = helpers.resolveFromHostOrUser config [ "displays" "mainIsWidescreen" ] true;
                fallbackWallpaper =
                  if isWidescreen then
                    self.inputs.nix-season-wallpaper.fallback.widescreen.path
                  else
                    self.inputs.nix-season-wallpaper.fallback.normal.path;
              in
              if (wallpaper.configPath or null) != null then
                self.config.filesPath wallpaper.configPath
              else if
                (wallpaper.url or null) != null
                && (wallpaper.url.url or null) != null
                && (wallpaper.url.hash or null) != null
              then
                pkgs.fetchurl {
                  url = wallpaper.url.url;
                  hash = wallpaper.url.hash;
                }
              else if (wallpaper.localPath or null) != null then
                wallpaper.localPath
              else
                fallbackWallpaper;

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
      enabled =
        config:
        let
          shared = stylixConfig config;
          isWidescreen = helpers.resolveFromHostOrUser config [ "displays" "mainIsWidescreen" ] true;
          fallbackWallpaperData =
            if isWidescreen then
              self.inputs.nix-season-wallpaper.fallback.widescreen
            else
              self.inputs.nix-season-wallpaper.fallback.normal;
          stylixExtension =
            let
              stylixExt = config.nx.common.style.stylix.wallpaper.extension;
              derivedExt = lib.last (lib.splitString "." shared.stylixAttrs.image);
            in
            if stylixExt != null && stylixExt != "" then stylixExt else derivedExt;
        in
        {
          nx.common.style.stylix.resolvedWallpaper.source = shared.stylixAttrs.image;
          nx.common.style.stylix.resolvedWallpaper.extension =
            if shared.stylixAttrs.image == fallbackWallpaperData.path then
              fallbackWallpaperData.extension
            else
              stylixExtension;

          nx.common.style.stylix.resolvedFonts = shared.stylixAttrs.fonts;
          nx.common.style.stylix.resolvedCursor = shared.stylixAttrs.cursor;
        };

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

      darwin.home =
        config:
        let
          shared = stylixConfig config;
          image = shared.stylixAttrs.image;
        in
        lib.mkIf (image != null && image != "") (
          let
            set-wallpaper-all-spaces = pkgs.writeShellScript "set-wallpaper-all-spaces" ''
              set -euo pipefail

              wallpaper="$1"

              if [ ! -f "$wallpaper" ]; then
                exit 1
              fi

              index="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

              if [ ! -f "$index" ]; then
                echo "error: missing wallpaper plist: $index" >&2
                exit 1
              fi

              cp "$index" "$index.bak"

              ${pkgs.python3}/bin/python3 - "$index" "$wallpaper" <<'PY'
              import plistlib
              import sys
              from urllib.parse import quote

              index, path = sys.argv[1], sys.argv[2]

              with open(index, "rb") as f:
                  root = plistlib.load(f)

              def expect_dict(obj, key, where):
                  value = obj.get(key)
                  if not isinstance(value, dict):
                      raise SystemExit(
                          f"error: expected dict at {where}:{key}, got {type(value).__name__}\n"
                          “Open System Settings -> Wallpaper, set an image manually, “
                          “enable 'Show on all Spaces', then run sync again.”
                      )
                  return value

              def expect_list(obj, key, where):
                  value = obj.get(key)
                  if not isinstance(value, list) or not value:
                      raise SystemExit(
                          f"error: expected non-empty list at {where}:{key}, got {type(value).__name__}\n"
                          “Open System Settings -> Wallpaper, set an image manually, “
                          “enable 'Show on all Spaces', then run sync again.”
                      )
                  return value

              all_spaces = expect_dict(root, "AllSpacesAndDisplays", "")
              desktop = expect_dict(all_spaces, "Desktop", "AllSpacesAndDisplays")
              content = expect_dict(desktop, "Content", "AllSpacesAndDisplays:Desktop")
              choices = expect_list(content, "Choices", "AllSpacesAndDisplays:Desktop:Content")

              choice = choices[0]
              if not isinstance(choice, dict):
                  raise SystemExit(
                      f"error: expected dict at Choices:0, got {type(choice).__name__}"
                  )

              inner = {
                  "type": "imageFile",
                  "url": {
                      "relative": "file://" + quote(path),
                  },
              }

              choice["Configuration"] = plistlib.dumps(inner, fmt=plistlib.FMT_BINARY)

              files = choice.get("Files")
              if isinstance(files, list) and files and isinstance(files[0], dict):
                  files[0]["relative"] = "file://" + quote(path)

              with open(index, "wb") as f:
                  plistlib.dump(root, f, fmt=plistlib.FMT_BINARY)
              PY

              /usr/bin/killall WallpaperAgent 2>/dev/null || true
            '';
          in
          {
            home.activation.setWallpaper = (self.hmLib config).dag.entryAfter [ "writeBoundary" ] ''
              echo "Set wallpaper to ${toString image}"

              export _NX_WALLPAPER=${lib.escapeShellArg (toString image)}

              ${set-wallpaper-all-spaces} ${lib.escapeShellArg (toString image)} \
                || /usr/bin/osascript -e 'tell application "System Events" to set picture of every desktop to (POSIX file (system attribute "_NX_WALLPAPER"))' \
                || true
            '';
          }
        );
    };
}
