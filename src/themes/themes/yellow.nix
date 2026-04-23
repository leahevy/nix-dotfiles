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
    name = "yellow";
    variant = "dark";
    tint = "yellow";
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
            html = "#2f2a5e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#2f2f11";
            name = "yellow";
            term = 58;
          };
        };
        foregrounds = {
          subtle = {
            html = "#7d7d68";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#999980";
            name = "yellow";
            term = 180;
          };
          primary = {
            html = "#efef59";
            name = "yellow";
            term = 227;
          };
          emphasized = {
            html = "#fff7cb";
            name = "bright-yellow";
            term = 229;
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
          html = "#FFEE67";
          name = "yellow";
          term = 227;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#665d30";
          name = "yellow";
          term = 58;
        };
        modified = {
          html = "#E8D880";
          name = "yellow";
          term = 186;
        };
        added = {
          html = "#FFEE00";
          name = "yellow";
          term = 226;
        };
        removed = {
          html = "#FFDD44";
          name = "yellow";
          term = 221;
        };
        selected = {
          html = "#7B6A3A";
          name = "yellow";
          term = 95;
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
          html = "#8c7d15";
          name = "yellow";
          term = 100;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#1a1600";
          name = "yellow";
          term = 58;
        };
        modifiedDarker = {
          html = "#7d6f2d";
          name = "yellow";
          term = 101;
        };
        addedDarker = {
          html = "#887510";
          name = "yellow";
          term = 142;
        };
        removedDarker = {
          html = "#996d05";
          name = "yellow";
          term = 136;
        };
        selectedDarker = {
          html = "#2c2605";
          name = "yellow";
          term = 58;
        };
        inactiveDarker = {
          html = "#050a30";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#a6a08c";
          name = "bright-black";
          term = 180;
        };
        normal = {
          html = "#7d7868";
          name = "bright-black";
          term = 101;
        };
        dark = {
          html = "#685f41";
          name = "bright-black";
          term = 95;
        };
        veryDark = {
          html = "#34322a";
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
            html = "#4d471a";
            name = "yellow";
            term = 58;
          };
          foreground = {
            html = "#efef59";
            name = "yellow";
            term = 227;
          };
        };
        selection = {
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
        accent = {
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
            html = "#7B6A3A";
            name = "yellow";
            term = 3;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#FFFF88";
            name = "bright-yellow";
            term = 11;
          };
          secondary = {
            html = "#E8E8B8";
            name = "bright-yellow";
            term = 11;
          };
          bright = {
            html = "#C0C060";
            name = "yellow";
            term = 3;
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
            html = "#EEDD88";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#FFFFAA";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#D4B830";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#FFFF55";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#FFFF00";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#B4B422";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#FFEE67";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#DAD050";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#E8E880";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#FFFFCB";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#65652A";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#EEEE88";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#FFF060";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#FFD93D";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#FFE040";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#FFF067";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#FFEE88";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "yellow";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
