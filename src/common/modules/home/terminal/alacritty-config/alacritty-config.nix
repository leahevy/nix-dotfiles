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
  name = "alacritty-config";

  group = "terminal";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      fonts = {
        nerdfonts = true;
      };
    };
  };

  settings = {
    fontSize = 12;
    opacity = 0.95;
    blur = true;
    setEnv = false;
    fontFamily = "DejaVuSansM Nerd Font Mono";
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.alacritty = {
        enable = true;
        package = lib.mkDefault (self.dummyPackage "alacritty");

        settings = {
          general = {
            ipc_socket = true;
            live_config_reload = true;
          };

          window = {
            opacity = lib.mkForce self.settings.opacity;
            blur = lib.mkForce self.settings.blur;
            padding = {
              x = 10;
              y = 10;
            };
            dynamic_padding = true;
            decorations = if self.isDarwin then "buttonless" else "full";
            option_as_alt = lib.mkIf self.isDarwin "Both";
          };

          font = {
            size = lib.mkForce self.settings.fontSize;
            normal = {
              family = lib.mkForce self.settings.fontFamily;
              style = "Regular";
            };
            bold = {
              family = lib.mkForce self.settings.fontFamily;
              style = "Bold";
            };
            italic = {
              family = lib.mkForce self.settings.fontFamily;
              style = "Italic";
            };
            bold_italic = {
              family = lib.mkForce self.settings.fontFamily;
              style = "Bold Italic";
            };
            builtin_box_drawing = true;
          };

          colors = {
            primary = {
              background = lib.mkForce self.theme.colors.terminal.normalBackgrounds.primary.html;
            };
          };

          keyboard = {
            bindings = [
              {
                key = "C";
                mods = "Control|Shift";
                action = "Copy";
              }
              {
                key = "V";
                mods = "Control|Shift";
                action = "Paste";
              }
              {
                key = "W";
                mods = "Control|Shift";
                action = "Quit";
              }
              {
                key = "N";
                mods = "Control|Shift";
                action = "CreateNewWindow";
              }
              {
                key = "Q";
                mods = "Control|Shift";
                action = "Quit";
              }
              {
                key = "Plus";
                mods = "Control";
                action = "IncreaseFontSize";
              }
              {
                key = "Equals";
                mods = "Control";
                action = "IncreaseFontSize";
              }
              {
                key = "Minus";
                mods = "Control";
                action = "DecreaseFontSize";
              }
              {
                key = "0";
                mods = "Control|Shift";
                action = "ResetFontSize";
              }
            ];
          };

          cursor = {
            style = {
              shape = "Block";
              blinking = "On";
            };
            blink_interval = 750;
            blink_timeout = 5;
            unfocused_hollow = true;
          };

          selection = {
            save_to_clipboard = true;
            semantic_escape_chars = ",│`|:\"' ()[]{}<>\t";
          };

          scrolling = {
            history = 10000;
            multiplier = 3;
          };

          bell = {
            animation = "EaseOutExpo";
            duration = 0;
            command = "None";
          };

          mouse = {
            hide_when_typing = true;
          };
        };
      };

      home.sessionVariables = lib.mkIf self.settings.setEnv {
        TERMINAL = "alacritty";
      };
    };
}
