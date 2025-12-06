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
  name = "red";
  group = "themes";
  input = "themes";
  namespace = "home";

  submodules = {
    themes = {
      base = {
        base = true;
      };
    };
  };

  settings = {
    name = "red";
    variant = "dark";
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
            html = "#372e5e";
            name = "bright-black";
            term = 59;
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
      };
      blocks = {
        block1 = {
          background = {
            html = "#ef5959";
            name = "red";
            term = 203;
          };
          foreground = {
            html = "#4d1a1a";
            name = "red";
            term = 52;
          };
        };
        block2 = {
          background = {
            html = "#4d1a33";
            name = "magenta";
            term = 53;
          };
          foreground = {
            html = "#ff6b9d";
            name = "magenta";
            term = 206;
          };
        };
      };
      terminal = rec {
        normalBackgrounds = {
          primary = {
            html = "#000000";
          };
          secondary = {
            html = "#111111";
          };
          highlight = {
            html = "#000000";
          };
          selection = {
            html = "#7B3A45";
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#FF8888";
          };
          secondary = {
            html = "#E8B8B8";
          };
          bright = {
            html = "#C09060";
          };
          dim = {
            html = "#3b4261";
          };
        };
        colors = {
          black = {
            html = "#414868";
          };
          cyan = {
            html = "#EE88AA";
          };
          cyanBright = {
            html = "#FF685F";
          };
          cyanDark = {
            html = "#EE30B5";
          };
          green = {
            html = "#E18800";
          };
          greenBright = {
            html = "#EE0044";
          };
          greenDark = {
            html = "#B42222";
          };
          yellow = {
            html = "#FF6774";
          };
          yellowDark = {
            html = "#DA5050";
          };
          magenta = {
            html = "#C84040";
          };
          magentaLight = {
            html = "#E88080";
          };
          magentaDark = {
            html = "#652A2A";
          };
          purple = {
            html = "#BB4077";
          };
          pink = {
            html = "#FF6073";
          };
          orange = {
            html = "#C04088";
          };
          red = {
            html = "#FF2088";
          };
          redBright = {
            html = "#ff3050";
          };
        };
      };
    };
  };
}
