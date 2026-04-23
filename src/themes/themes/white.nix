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
    name = "white";
    variant = "dark";
    tint = "white";
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
            html = "#2c2f3a";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#1a1a1a";
            name = "white";
            term = 236;
          };
        };
        foregrounds = {
          subtle = {
            html = "#7d7d7d";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#b0b0b0";
            name = "white";
            term = 250;
          };
          primary = {
            html = "#e0e0e0";
            name = "white";
            term = 254;
          };
          emphasized = {
            html = "#ffffff";
            name = "white";
            term = 255;
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
          html = "#eeeeee";
          name = "white";
          term = 255;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#666666";
          name = "bright-black";
          term = 242;
        };
        modified = {
          html = "#cccccc";
          name = "white";
          term = 252;
        };
        added = {
          html = "#ffffff";
          name = "white";
          term = 255;
        };
        removed = {
          html = "#aaaaaa";
          name = "white";
          term = 248;
        };
        selected = {
          html = "#444444";
          name = "bright-black";
          term = 238;
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
          html = "#bbbbbb";
          name = "white";
          term = 250;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#1a1a1a";
          name = "bright-black";
          term = 236;
        };
        modifiedDarker = {
          html = "#7d7d7d";
          name = "bright-black";
          term = 244;
        };
        addedDarker = {
          html = "#e0e0e0";
          name = "white";
          term = 254;
        };
        removedDarker = {
          html = "#555555";
          name = "bright-black";
          term = 240;
        };
        selectedDarker = {
          html = "#222222";
          name = "bright-black";
          term = 235;
        };
        inactiveDarker = {
          html = "#050a30";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#a6a6a6";
          name = "bright-black";
          term = 248;
        };
        normal = {
          html = "#7d7d7d";
          name = "bright-black";
          term = 244;
        };
        dark = {
          html = "#686868";
          name = "bright-black";
          term = 242;
        };
        veryDark = {
          html = "#343434";
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
            html = "#333333";
            name = "bright-black";
            term = 236;
          };
          foreground = {
            html = "#eeeeee";
            name = "white";
            term = 255;
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
            html = "#333333";
            name = "bright-black";
            term = 236;
          };
          foreground = {
            html = "#eeeeee";
            name = "white";
            term = 255;
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
            html = "#444444";
            name = "bright-black";
            term = 8;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#EEEEEE";
            name = "white";
            term = 15;
          };
          secondary = {
            html = "#CCCCCC";
            name = "white";
            term = 7;
          };
          bright = {
            html = "#FFFFFF";
            name = "white";
            term = 15;
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
            html = "#b0b0b0";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#e0e0e0";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#808080";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#b0b0b0";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#ffffff";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#8c8c8c";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#d0d0d0";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#a6a6a6";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#c0c0c0";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#e0e0e0";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#686868";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#d0d0d0";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#f0f0f0";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#cccccc";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#e0e0e0";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#ffffff";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#d0d0d0";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "white";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
