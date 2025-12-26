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
rec {
  name = "red";

  group = "themes";
  input = "themes";
  namespace = "home";

  settings = {
    inherit name;
    variant = "dark";
    tint = "red";
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
    icons = "papirus-icon-theme/Papirus";
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
            html = "#231e5e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#38080b";
            name = "red";
            term = 52;
          };
        };
        foregrounds = {
          subtle = {
            html = "#7d6868";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#998080";
            name = "red";
            term = 138;
          };
          primary = {
            html = "#ef5959";
            name = "red";
            term = 203;
          };
          emphasized = {
            html = "#ffcbcb";
            name = "bright-red";
            term = 217;
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
          html = "#FF685F";
          name = "red";
          term = 203;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#664030";
          name = "red";
          term = 52;
        };
        modified = {
          html = "#E88080";
          name = "red";
          term = 174;
        };
        added = {
          html = "#EE0044";
          name = "red";
          term = 197;
        };
        removed = {
          html = "#ff3050";
          name = "red";
          term = 203;
        };
        selected = {
          html = "#7B3A45";
          name = "red";
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
          html = "#b81c15";
          name = "red";
          term = 203;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#1a0f00";
          name = "red";
          term = 52;
        };
        modifiedDarker = {
          html = "#7d2d2c";
          name = "red";
          term = 174;
        };
        addedDarker = {
          html = "#770008";
          name = "red";
          term = 197;
        };
        removedDarker = {
          html = "#990515";
          name = "red";
          term = 203;
        };
        selectedDarker = {
          html = "#2c0512";
          name = "red";
          term = 95;
        };
        inactiveDarker = {
          html = "#0f0a1f";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#a68c8c";
          name = "bright-black";
          term = 138;
        };
        normal = {
          html = "#7d6868";
          name = "bright-black";
          term = 95;
        };
        dark = {
          html = "#684141";
          name = "bright-black";
          term = 95;
        };
        veryDark = {
          html = "#312734";
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
            html = "#4d1a1a";
            name = "red";
            term = 52;
          };
          foreground = {
            html = "#ef5959";
            name = "red";
            term = 203;
          };
        };
        selection = {
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
        accent = {
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
            html = "#7B3A45";
            name = "red";
            term = 1;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#FF8888";
            name = "bright-red";
            term = 9;
          };
          secondary = {
            html = "#E8B8B8";
            name = "red";
            term = 1;
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
            html = "#EE88AA";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#FF685F";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#EE30B5";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#E18800";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#EE0044";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#B42222";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#FF6774";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#DA5050";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#C84040";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#E88080";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#652A2A";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#BB4077";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#FF6073";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#C04088";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#FF2088";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#ff3050";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#FF4088";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
}
