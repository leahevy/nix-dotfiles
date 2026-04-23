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
    name = "blue";
    variant = "dark";
    tint = "blue";
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
            html = "#112a6e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#0b1138";
            name = "blue";
            term = 18;
          };
        };
        foregrounds = {
          subtle = {
            html = "#68717d";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#8090a6";
            name = "blue";
            term = 103;
          };
          primary = {
            html = "#59a6ef";
            name = "blue";
            term = 75;
          };
          emphasized = {
            html = "#cbd5ff";
            name = "bright-blue";
            term = 189;
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
          html = "#5FA5FF";
          name = "blue";
          term = 75;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#304066";
          name = "blue";
          term = 24;
        };
        modified = {
          html = "#80B0E8";
          name = "blue";
          term = 110;
        };
        added = {
          html = "#0088FF";
          name = "blue";
          term = 33;
        };
        removed = {
          html = "#44AAFF";
          name = "blue";
          term = 75;
        };
        selected = {
          html = "#3A457B";
          name = "blue";
          term = 60;
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
          html = "#155a8c";
          name = "blue";
          term = 75;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#000f1a";
          name = "blue";
          term = 24;
        };
        modifiedDarker = {
          html = "#2d4d7d";
          name = "blue";
          term = 110;
        };
        addedDarker = {
          html = "#104a88";
          name = "blue";
          term = 33;
        };
        removedDarker = {
          html = "#055599";
          name = "blue";
          term = 75;
        };
        selectedDarker = {
          html = "#05122c";
          name = "blue";
          term = 60;
        };
        inactiveDarker = {
          html = "#050a30";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#8c97a6";
          name = "bright-black";
          term = 103;
        };
        normal = {
          html = "#68717d";
          name = "bright-black";
          term = 60;
        };
        dark = {
          html = "#414b68";
          name = "bright-black";
          term = 60;
        };
        veryDark = {
          html = "#273134";
          name = "bright-black";
          term = 59;
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
            html = "#1a2655";
            name = "blue";
            term = 18;
          };
          foreground = {
            html = "#59a6ef";
            name = "blue";
            term = 75;
          };
        };
        selection = {
          background = {
            html = "#4d331a";
            name = "yellow";
            term = 58;
          };
          foreground = {
            html = "#ef9959";
            name = "yellow";
            term = 209;
          };
        };
        accent = {
          background = {
            html = "#1a2655";
            name = "blue";
            term = 18;
          };
          foreground = {
            html = "#59a6ef";
            name = "blue";
            term = 75;
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
            html = "#3A457B";
            name = "blue";
            term = 4;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#88AAFF";
            name = "bright-blue";
            term = 12;
          };
          secondary = {
            html = "#B8C8E8";
            name = "bright-blue";
            term = 12;
          };
          bright = {
            html = "#6090C0";
            name = "blue";
            term = 4;
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
            html = "#88AAEE";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#5FA5FF";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#3088EE";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#2088FF";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#0055FF";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#226CB4";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#67A0FF";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#5080DA";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#40A0C8";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#80B0E8";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#2A3065";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#4077BB";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#6073FF";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#4088C0";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#2088FF";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#3050FF";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#4090FF";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "blue";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
