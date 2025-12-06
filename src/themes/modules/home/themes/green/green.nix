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
  name = "green";
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
    name = "green";
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
            html = "#254837";
            name = "bright-black";
            term = 59;
          };
        };
        foregrounds = {
          subtle = {
            html = "#687d68";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#809980";
            name = "cyan";
            term = 108;
          };
          primary = {
            html = "#59ef99";
            name = "green";
            term = 84;
          };
          emphasized = {
            html = "#cbffa9";
            name = "bright-green";
            term = 121;
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
          html = "#5FFFC8";
          name = "cyan";
          term = 87;
        };
        hint = {
          html = "#306640";
          name = "green";
          term = 22;
        };
        modified = {
          html = "#80E8A0";
          name = "green";
          term = 114;
        };
        added = {
          html = "#00FF55";
          name = "bright-green";
          term = 47;
        };
        removed = {
          html = "#44ee00";
          name = "green";
          term = 82;
        };
        selected = {
          html = "#3A7B45";
          name = "green";
          term = 65;
        };
        inactive = {
          html = "#3b4261";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#8ca68c";
          name = "bright-black";
          term = 102;
        };
        normal = {
          html = "#687d68";
          name = "bright-black";
          term = 66;
        };
        dark = {
          html = "#414868";
          name = "bright-black";
          term = 59;
        };
      };
      blocks = {
        block1 = {
          background = {
            html = "#37f499";
            name = "green";
            term = 46;
          };
          foreground = {
            html = "#1a4d33";
            name = "green";
            term = 22;
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
            html = "#3A7B45";
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#ffFF88";
          };
          secondary = {
            html = "#B8E8B8";
          };
          bright = {
            html = "#60C090";
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
            html = "#88EEAA";
          };
          cyanBright = {
            html = "#5FFFC8";
          };
          cyanDark = {
            html = "#30EEB5";
          };
          green = {
            html = "#20FF88";
          };
          greenBright = {
            html = "#00FF55";
          };
          greenDark = {
            html = "#22B46C";
          };
          yellow = {
            html = "#74FF67";
          };
          yellowDark = {
            html = "#AFDA50";
          };
          magenta = {
            html = "#40C8A0";
          };
          magentaLight = {
            html = "#80E8A0";
          };
          magentaDark = {
            html = "#2A6530";
          };
          purple = {
            html = "#40BB77";
          };
          pink = {
            html = "#73ff60";
          };
          orange = {
            html = "#88C040";
          };
        };
      };
    };
  };
}
