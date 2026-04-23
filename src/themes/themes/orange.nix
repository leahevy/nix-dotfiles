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
    name = "orange";
    variant = "dark";
    tint = "orange";
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
            html = "#3a2a5e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#2f1f11";
            name = "yellow";
            term = 58;
          };
        };
        foregrounds = {
          subtle = {
            html = "#7d7368";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#998f80";
            name = "yellow";
            term = 180;
          };
          primary = {
            html = "#ef9959";
            name = "yellow";
            term = 209;
          };
          emphasized = {
            html = "#ffddb5";
            name = "bright-yellow";
            term = 223;
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
          html = "#FFB15F";
          name = "yellow";
          term = 215;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#663b1a";
          name = "yellow";
          term = 58;
        };
        modified = {
          html = "#E8B080";
          name = "yellow";
          term = 180;
        };
        added = {
          html = "#FF8800";
          name = "yellow";
          term = 208;
        };
        removed = {
          html = "#FFAA44";
          name = "yellow";
          term = 215;
        };
        selected = {
          html = "#7B5A3A";
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
          html = "#8c5a15";
          name = "yellow";
          term = 215;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#1a1200";
          name = "yellow";
          term = 58;
        };
        modifiedDarker = {
          html = "#7d5a2d";
          name = "yellow";
          term = 180;
        };
        addedDarker = {
          html = "#884a10";
          name = "yellow";
          term = 208;
        };
        removedDarker = {
          html = "#995505";
          name = "yellow";
          term = 215;
        };
        selectedDarker = {
          html = "#2c1a05";
          name = "yellow";
          term = 95;
        };
        inactiveDarker = {
          html = "#050a30";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#a69a8c";
          name = "bright-black";
          term = 247;
        };
        normal = {
          html = "#7d7468";
          name = "bright-black";
          term = 243;
        };
        dark = {
          html = "#684f41";
          name = "bright-black";
          term = 239;
        };
        veryDark = {
          html = "#34302a";
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
            html = "#7B5A3A";
            name = "yellow";
            term = 3;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#FFDD88";
            name = "bright-yellow";
            term = 11;
          };
          secondary = {
            html = "#E8D0B8";
            name = "bright-yellow";
            term = 11;
          };
          bright = {
            html = "#C09060";
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
            html = "#EEAA88";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#FFCCAA";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#EE8840";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#E18800";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#FF8800";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#B45C22";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#FFB347";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#DA8A50";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#C87040";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#E8B080";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#653A2A";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#BB7740";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#FFAA60";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#C08040";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#FF7040";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#FF9955";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#FF9060";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "orange";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
