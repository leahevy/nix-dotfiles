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
    name = "purple";
    variant = "dark";
    tint = "purple";
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
            html = "#1e235e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#1d0b2f";
            name = "magenta";
            term = 53;
          };
        };
        foregrounds = {
          subtle = {
            html = "#73687d";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#9080a6";
            name = "magenta";
            term = 103;
          };
          primary = {
            html = "#a659ef";
            name = "magenta";
            term = 141;
          };
          emphasized = {
            html = "#e2cbff";
            name = "bright-magenta";
            term = 183;
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
          html = "#A67BFF";
          name = "magenta";
          term = 141;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#403066";
          name = "magenta";
          term = 60;
        };
        modified = {
          html = "#B080E8";
          name = "magenta";
          term = 140;
        };
        added = {
          html = "#7D00FF";
          name = "bright-magenta";
          term = 93;
        };
        removed = {
          html = "#AA44FF";
          name = "magenta";
          term = 135;
        };
        selected = {
          html = "#533A7B";
          name = "magenta";
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
          html = "#3a158c";
          name = "magenta";
          term = 54;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#0f001a";
          name = "magenta";
          term = 53;
        };
        modifiedDarker = {
          html = "#4d2d7d";
          name = "magenta";
          term = 60;
        };
        addedDarker = {
          html = "#4a1088";
          name = "bright-magenta";
          term = 54;
        };
        removedDarker = {
          html = "#550599";
          name = "magenta";
          term = 54;
        };
        selectedDarker = {
          html = "#16052c";
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
          html = "#9b8ca6";
          name = "bright-black";
          term = 103;
        };
        normal = {
          html = "#73687d";
          name = "bright-black";
          term = 60;
        };
        dark = {
          html = "#534168";
          name = "bright-black";
          term = 60;
        };
        veryDark = {
          html = "#2f2a34";
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
            html = "#3a1a4d";
            name = "magenta";
            term = 53;
          };
          foreground = {
            html = "#a659ef";
            name = "magenta";
            term = 141;
          };
        };
        selection = {
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
        accent = {
          background = {
            html = "#3a1a4d";
            name = "magenta";
            term = 53;
          };
          foreground = {
            html = "#a659ef";
            name = "magenta";
            term = 141;
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
            html = "#533A7B";
            name = "magenta";
            term = 5;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#B388FF";
            name = "bright-magenta";
            term = 13;
          };
          secondary = {
            html = "#D0B8E8";
            name = "magenta";
            term = 5;
          };
          bright = {
            html = "#9060C0";
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
            html = "#88A0EE";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#A685FF";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#3050EE";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#8855FF";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#7D00FF";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#6C22B4";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#A067FF";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#8050DA";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#8040C8";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#B080E8";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#302A65";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#7740BB";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#7360FF";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#8840C0";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#8820FF";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#5030FF";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#9040FF";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "purple";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
