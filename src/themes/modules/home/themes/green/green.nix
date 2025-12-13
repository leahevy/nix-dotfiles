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
  name = "green";

  group = "themes";
  input = "themes";
  namespace = "home";

  settings = {
    inherit name;
    variant = "dark";
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
            html = "#13345e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#182f11";
            name = "green";
            term = 22;
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
          html = "#158c70";
          name = "cyan";
          term = 87;
        };
        hintDarker = {
          html = "#001a03";
          name = "green";
          term = 22;
        };
        modifiedDarker = {
          html = "#2d7054";
          name = "green";
          term = 114;
        };
        addedDarker = {
          html = "#4a8810";
          name = "bright-green";
          term = 47;
        };
        removedDarker = {
          html = "#0a5500";
          name = "green";
          term = 82;
        };
        selectedDarker = {
          html = "#042308";
          name = "green";
          term = 65;
        };
        inactiveDarker = {
          html = "#050a30";
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
        veryDark = {
          html = "#313734";
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
        selection = {
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
        accent = {
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
            html = "#3A7B45";
            name = "green";
            term = 2;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#ffFF88";
            name = "bright-yellow";
            term = 11;
          };
          secondary = {
            html = "#B8E8B8";
            name = "bright-green";
            term = 10;
          };
          bright = {
            html = "#60C090";
            name = "green";
            term = 2;
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
            html = "#88EEAA";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#5FFFC8";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#30EEB5";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#20FF88";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#00FF55";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#22B46C";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#74FF67";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#AFDA50";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#40C8A0";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#80E8A0";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#2A6530";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#40BB77";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#73ff60";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#88C040";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#20FF88";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#00FF55";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#20FF99";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
}
