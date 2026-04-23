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
    name = "cyan";
    variant = "dark";
    tint = "cyan";
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
            html = "#0f3a5e";
            name = "bright-black";
            term = 59;
          };
          themed = {
            html = "#0b2a2a";
            name = "cyan";
            term = 23;
          };
        };
        foregrounds = {
          subtle = {
            html = "#687d7d";
            name = "bright-black";
            term = 8;
          };
          secondary = {
            html = "#80a6a6";
            name = "cyan";
            term = 109;
          };
          primary = {
            html = "#59efdd";
            name = "cyan";
            term = 86;
          };
          emphasized = {
            html = "#cbfff6";
            name = "bright-cyan";
            term = 195;
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
          html = "#5FFFF2";
          name = "cyan";
          term = 87;
        };
        hint = {
          html = "#11c0ff";
          name = "blue";
          term = 18;
        };
        comment = {
          html = "#306664";
          name = "cyan";
          term = 30;
        };
        modified = {
          html = "#80E8E0";
          name = "cyan";
          term = 122;
        };
        added = {
          html = "#00FFF2";
          name = "bright-cyan";
          term = 51;
        };
        removed = {
          html = "#44EEFF";
          name = "cyan";
          term = 81;
        };
        selected = {
          html = "#3A7B77";
          name = "cyan";
          term = 66;
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
          html = "#158c84";
          name = "cyan";
          term = 30;
        };
        hintDarker = {
          html = "#2244aa";
          name = "blue";
          term = 18;
        };
        commentDarker = {
          html = "#001a18";
          name = "cyan";
          term = 23;
        };
        modifiedDarker = {
          html = "#2d7d70";
          name = "cyan";
          term = 30;
        };
        addedDarker = {
          html = "#10887d";
          name = "bright-cyan";
          term = 30;
        };
        removedDarker = {
          html = "#059999";
          name = "cyan";
          term = 30;
        };
        selectedDarker = {
          html = "#052c24";
          name = "cyan";
          term = 23;
        };
        inactiveDarker = {
          html = "#050a30";
          name = "bright-black";
          term = 59;
        };
      };
      separators = {
        light = {
          html = "#8ca6a6";
          name = "bright-black";
          term = 109;
        };
        normal = {
          html = "#687d7d";
          name = "bright-black";
          term = 66;
        };
        dark = {
          html = "#416868";
          name = "bright-black";
          term = 59;
        };
        veryDark = {
          html = "#2a3434";
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
            html = "#1a4d4a";
            name = "cyan";
            term = 23;
          };
          foreground = {
            html = "#59efdd";
            name = "cyan";
            term = 86;
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
            html = "#1a4d4a";
            name = "cyan";
            term = 23;
          };
          foreground = {
            html = "#59efdd";
            name = "cyan";
            term = 86;
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
            html = "#3A7B77";
            name = "cyan";
            term = 6;
          };
        };
        transparencyBackgrounds = normalBackgrounds // {
          secondary = null;
        };
        foregrounds = {
          primary = {
            html = "#88FFFF";
            name = "bright-cyan";
            term = 14;
          };
          secondary = {
            html = "#B8E8E8";
            name = "bright-cyan";
            term = 14;
          };
          bright = {
            html = "#60C0C0";
            name = "cyan";
            term = 6;
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
            html = "#20FFEE";
            name = "cyan";
            term = 6;
          };
          cyanBright = {
            html = "#5FFFF2";
            name = "bright-cyan";
            term = 14;
          };
          cyanDark = {
            html = "#22B4A8";
            name = "cyan";
            term = 6;
          };
          green = {
            html = "#20FFEE";
            name = "green";
            term = 2;
          };
          greenBright = {
            html = "#00FFF2";
            name = "bright-green";
            term = 10;
          };
          greenDark = {
            html = "#22B4A8";
            name = "green";
            term = 2;
          };
          yellow = {
            html = "#67FFF4";
            name = "yellow";
            term = 3;
          };
          yellowDark = {
            html = "#50DAD0";
            name = "yellow";
            term = 3;
          };
          magenta = {
            html = "#40C8C8";
            name = "magenta";
            term = 5;
          };
          magentaLight = {
            html = "#80E8E0";
            name = "bright-magenta";
            term = 13;
          };
          magentaDark = {
            html = "#2A6565";
            name = "magenta";
            term = 5;
          };
          purple = {
            html = "#40BBBB";
            name = "magenta";
            term = 5;
          };
          pink = {
            html = "#60FFF6";
            name = "bright-magenta";
            term = 13;
          };
          orange = {
            html = "#40C0B0";
            name = "yellow";
            term = 3;
          };
          red = {
            html = "#20FFE0";
            name = "red";
            term = 1;
          };
          redBright = {
            html = "#00FFF2";
            name = "bright-red";
            term = 9;
          };
          blue = {
            html = "#20FFF8";
            name = "blue";
            term = 4;
          };
        };
      };
    };
  };
in
{
  name = "cyan";

  group = "themes";
  input = "themes";

  module = {
    enabled = config: {
      nx.preferences.theme = themeData;
    };
  };
}
