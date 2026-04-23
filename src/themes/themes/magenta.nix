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
let
  themeData = {
    name = "magenta";
    variant = "dark";
    tint = "magenta";
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
    icons = {
      primary = "cosmic-icons/Cosmic";
      fallback = "papirus-icon-theme/Papirus";
    };
    cursor = {
      style = "rose-pine-cursor/BreezeX-RosePine-Linux";
      size = 40;
    };
    colors = {
      main = {
        backgrounds = {
          primary = {
            html = "#000000";
            name = "black";
            term = 0;
          };
          secondary = {
            html = "#000000";
            name = "black";
            term = 0;
          };
          tertiary = {
            html = "#3a0f5e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#2a0b2a";
            name = "magenta";
            term = 53;
          };
        };
        foregrounds = {
          subtle = {
            html = "#7d687d";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#a680a6";
            name = "magenta";
            term = 139;
          };
          primary = {
            html = "#ef59d5";
            name = "magenta";
            term = 170;
          };
          emphasized = {
            html = "#ffcbf4";
            name = "bright-magenta";
            term = 219;
          };
          strong = {
            html = "#eeeeee";
            name = "white";
            term = 255;
          };
        };
        base = {
          red = {
            html = "#e6193c";
            name = "red";
            term = 1;
          };
          orange = {
            html = "#87711d";
            name = "yellow";
            term = 3;
          };
          yellow = {
            html = "#98981b";
            name = "bright-yellow";
            term = 11;
          };
          green = {
            html = "#29a329";
            name = "green";
            term = 2;
          };
          cyan = {
            html = "#1999b3";
            name = "cyan";
            term = 6;
          };
          blue = {
            html = "#3d62f5";
            name = "blue";
            term = 4;
          };
          purple = {
            html = "#ad2bee";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#e619c3";
            name = "bright-magenta";
            term = 13;
          };
        };
      };
      semantic = {
        success = {
          html = "#37f499";
          name = "green";
          term = 46;
        };
        warning = {
          html = "#FFFF67";
          name = "yellow";
          term = 226;
        };
        error = {
          html = "#E07575";
          name = "red";
          term = 203;
        };
        info = {
          html = "#FF5FC8";
          name = "magenta";
          term = 205;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#663056";
          name = "magenta";
          term = 53;
        };
        modified = {
          html = "#E880C8";
          name = "magenta";
          term = 176;
        };
        added = {
          html = "#FF00D5";
          name = "bright-magenta";
          term = 199;
        };
        removed = {
          html = "#FF44EE";
          name = "magenta";
          term = 207;
        };
        selected = {
          html = "#7B3A65";
          name = "magenta";
          term = 96;
        };
        inactive = {
          html = "#3b4261";
          name = "bright-black";
          term = 59;
        };
        successDarker = {
          html = "#1b8544";
          name = "green";
          term = 46;
        };
        warningDarker = {
          html = "#b8b820";
          name = "yellow";
          term = 226;
        };
        errorDarker = {
          html = "#8a2a2a";
          name = "red";
          term = 203;
        };
        infoDarker = {
          html = "#8c1570";
          name = "magenta";
          term = 90;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#1a0012";
          name = "magenta";
          term = 53;
        };
        modifiedDarker = {
          html = "#7d2d54";
          name = "magenta";
          term = 90;
        };
        addedDarker = {
          html = "#88104a";
          name = "bright-magenta";
          term = 90;
        };
        removedDarker = {
          html = "#990555";
          name = "magenta";
          term = 90;
        };
        selectedDarker = {
          html = "#2c051f";
          name = "magenta";
          term = 53;
        };
        inactiveDarker = {
          html = "#050a30";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#a68ca6";
          name = "bright-black";
          term = 139;
        };
        normal = {
          html = "#7d687d";
          name = "bright-black";
          term = 96;
        };
        dark = {
          html = "#684168";
          name = "bright-black";
          term = 96;
        };
        veryDark = {
          html = "#342a34";
          name = "bright-black";
          term = 236;
        };
        ultraDark = {
          html = "#211722";
          name = "bright-black";
          term = 59;
        };
      };
      blocks = {
        primary = {
          background = {
            html = "#4d1a44";
            name = "magenta";
            term = 53;
          };
          foreground = {
            html = "#ef59d5";
            name = "magenta";
            term = 170;
          };
        };
        selection = {
          background = {
            html = "#1a4d33";
            name = "green";
            term = 22;
          };
          foreground = {
            html = "#37f499";
            name = "green";
            term = 46;
          };
        };
        accent = {
          background = {
            html = "#4d1a44";
            name = "magenta";
            term = 53;
          };
          foreground = {
            html = "#ef59d5";
            name = "magenta";
            term = 170;
          };
        };
        highlight = {
          background = {
            html = "#3d2644";
            name = "magenta";
            term = 53;
          };
          foreground = {
            html = "#c678dd";
            name = "magenta";
            term = 5;
          };
        };
        warning = {
          background = {
            html = "#4d4d1a";
            name = "yellow";
            term = 58;
          };
          foreground = {
            html = "#ffd93d";
            name = "bright-yellow";
            term = 11;
          };
        };
        critical = {
          background = {
            html = "#4d1a1a";
            name = "red";
            term = 52;
          };
          foreground = {
            html = "#ff4444";
            name = "red";
            term = 1;
          };
        };
        info = {
          background = {
            html = "#0a3344";
            name = "cyan";
            term = 23;
          };
          foreground = {
            html = "#1999b3";
            name = "cyan";
            term = 6;
          };
        };
        neutral = {
          background = {
            html = "#1a2655";
            name = "blue";
            term = 18;
          };
          foreground = {
            html = "#3d62f5";
            name = "blue";
            term = 4;
          };
        };
      };
      terminal = rec {
        normalBackgrounds = {
          primary = {
            html = "#000000";
            name = "black";
            term = 0;
          };
          secondary = {
            html = "#0f0f0f";
            name = "bright-black";
            term = 8;
          };
          tertiary = {
            html = "#0a0a0a";
            name = "black";
            term = 0;
          };
          highlight = {
            html = "#111111";
            name = "black";
            term = 0;
          };
          selection = {
            html = "#7B3A65";
            name = "magenta";
            term = 5;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#FF88FF";
            name = "bright-magenta";
            term = 13;
          };
          secondary = {
            html = "#E8B8E8";
            name = "magenta";
            term = 5;
          };
          bright = {
            html = "#C060C0";
            name = "magenta";
            term = 5;
          };
          dim = {
            html = "#3b4261";
            name = "bright-black";
            term = 8;
          };
        };
        colors = {
          black = {
            html = "#414868";
            name = "bright-black";
            term = 8;
          };
          cyan = {
            html = "#EE88FF";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#FF68F0";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#B530EE";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#E188FF";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#FF00D5";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#B422B4";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#FF67D4";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#DA50B8";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#C840C8";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#E880E8";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#652A65";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#BB40BB";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#FF60F0";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#C040C0";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#FF20D5";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#FF30EE";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#FF40FF";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "magenta";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
