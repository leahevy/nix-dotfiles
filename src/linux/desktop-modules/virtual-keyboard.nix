args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  hexToDec =
    hex:
    let
      digits = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
    in
    builtins.foldl' (acc: c: acc * 16 + digits.${c}) 0 (lib.stringToCharacters (lib.toLower hex));

  htmlToRgb =
    html:
    let
      s = lib.removePrefix "#" html;
    in
    {
      r = hexToDec (builtins.substring 0 2 s);
      g = hexToDec (builtins.substring 2 2 s);
      b = hexToDec (builtins.substring 4 2 s);
    };
in
{
  name = "virtual-keyboard";
  group = "desktop-modules";
  input = "linux";
  description = "Themed on-screen keyboard using wvkbd";

  options = {
    fontSize = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Font size for key labels, or null to derive from height.";
    };
    keyOpacity = lib.mkOption {
      type = lib.types.int;
      default = 255;
      description = "Alpha for key buttons from 0 (transparent) to 255 (opaque).";
    };
    bgOpacity = lib.mkOption {
      type = lib.types.int;
      default = 200;
      description = "Alpha for keyboard background from 0 (transparent) to 255 (opaque).";
    };
    cornerRadius = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Key corner radius in pixels.";
    };
    height = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 250;
      description = "Keyboard height in pixels, or null to use the wvkbd default (250).";
    };
    nonWidescreenScale = lib.mkOption {
      type = lib.types.float;
      default = 2.0 / 3.0;
      description = "Scale factor applied to height on non-widescreen displays.";
    };
  };

  module = {
    ifEnabled.linux.desktop.niri.home =
      {
        config,
        height,
        nonWidescreenScale,
        ...
      }:
      let
        isWidescreen = helpers.resolveFromHostOrUser config [ "displays" "mainIsWidescreen" ] false;
        effectiveHeight =
          if height == null then
            null
          else if isWidescreen then
            height
          else
            builtins.floor (height * nonWidescreenScale);
        heightFlag = lib.optionalString (
          effectiveHeight != null
        ) " -H ${toString effectiveHeight} -L ${toString effectiveHeight}";
      in
      {
        programs.niri.settings.binds = with config.lib.niri.actions; {
          "Mod+Ctrl+Alt+Space" = {
            action = spawn-sh "pgrep wvkbd-mobintl && pkill wvkbd-mobintl || wvkbd-mobintl${heightFlag}";
            hotkey-overlay.title = "Utils:Virtual Keyboard";
          };
        };
      };

    linux.home =
      {
        config,
        fontSize,
        keyOpacity,
        bgOpacity,
        cornerRadius,
        height,
        nonWidescreenScale,
        ...
      }:
      let
        theme = config.nx.preferences.theme;
        c = theme.colors;

        bg = htmlToRgb c.main.backgrounds.primary.html;
        fg = htmlToRgb c.blocks.primary.background.html;
        high = htmlToRgb c.blocks.accent.background.html;
        text = htmlToRgb c.blocks.primary.foreground.html;
        swipe = htmlToRgb c.blocks.primary.foreground.html;

        isWidescreen = helpers.resolveFromHostOrUser config [ "displays" "mainIsWidescreen" ] false;
        effectiveHeight =
          if height == null then
            250
          else if isWidescreen then
            height
          else
            builtins.floor (height * nonWidescreenScale);

        fontFamily = lib.last (lib.splitString "/" theme.fonts.monospace.path);
        effectiveFontSize =
          if fontSize != null then fontSize else builtins.floor (effectiveHeight * 25 / 350);
        font = "${fontFamily} ${toString effectiveFontSize}";

        bgra =
          color: a:
          "{.bgra = {${toString color.b}, ${toString color.g}, ${toString color.r}, ${toString a}}}";

        colorVal = color: a: toString (color.b + color.g * 256 + color.r * 65536 + a * 16777216);

        scheme = ''
          {
            .bg = ${bgra bg bgOpacity},
            .fg = ${bgra fg keyOpacity},
            .high = ${bgra high keyOpacity},
            .swipe = ${bgra swipe 64},
            .text = {.color = ${colorVal text keyOpacity}},
            .font = DEFAULT_FONT,
            .rounding = DEFAULT_ROUNDING,
          }'';

        configHeader = pkgs.writeText "config.mobintl.h" ''
          #ifndef config_h_INCLUDED
          #define config_h_INCLUDED

          #define DEFAULT_FONT "${font}"
          #define DEFAULT_ROUNDING ${toString cornerRadius}
          #define SHIFT_SPACE_IS_TAB
          static const int transparency = ${toString keyOpacity};

          struct clr_scheme schemes[] = {
          ${scheme},
          ${scheme}
          };

          static enum layout_id layers[] = {
            Full,
            Special,
            NumLayouts
          };

          static enum layout_id landscape_layers[] = {
            Landscape,
            LandscapeSpecial,
            NumLayouts
          };

          #endif
        '';

        themedWvkbd = pkgs.wvkbd.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            cp ${configHeader} config.mobintl.h
          '';
        });
      in
      {
        home.packages = [ themedWvkbd ];
      };
  };
}
