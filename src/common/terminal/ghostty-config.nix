args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "ghostty-config";

  group = "terminal";
  input = "common";

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
    blurOpacity = 0.90;
    shaders = [
      # "cursor_blaze"
      "cursor_blaze_light"
      "cursor_smear"
    ];
    setEnv = false;
    fontFamily = "DejaVuSansM Nerd Font Mono";
  };

  assertions = [
    {
      assertion =
        !(
          lib.elem "cursor_blaze" self.settings.shaders && lib.elem "cursor_blaze_light" self.settings.shaders
        );
      message = "ghostty-config: cursor_blaze and cursor_blaze_light are mutually exclusive!";
    }
  ];

  module = {
    enabled = config: {
      nx.preferences.desktop.programs.terminal = {
        name = "ghostty";
        package = null;
        openCommand = [ "ghostty" ];
        openDirectoryCommand = path: [
          "ghostty"
          "--working-directory=${path}"
        ];
        openRunCommand = cmd: [
          "ghostty"
          "-e"
          cmd
        ];
        openRunPrefix = [
          "ghostty"
          "-e"
        ];
        openShellCommand = cmd: [
          "ghostty"
          "-e"
          "sh"
          "-c"
          cmd
        ];
        openWithClass = class: [
          "ghostty"
          "--class=${class}"
        ];
        openRunWithClass = class: cmd: [
          "ghostty"
          "--class=${class}"
          "-e"
          cmd
        ];
        desktopFile = "com.mitchellh.ghostty.desktop";
      };
      nx.preferences.desktop.programs.additionalTerminal =
        lib.mkIf self.isLinux config.nx.preferences.desktop.programs.terminal;
    };

    home =
      config:
      let
        theme = config.nx.preferences.theme;
        trailHex = lib.removePrefix "#" theme.colors.terminal.foregrounds.primary.html;
        accentHex = lib.removePrefix "#" theme.colors.terminal.foregrounds.bright.html;
        easedProgressFactor =
          if self.isLinux then "0.0035 + lineLength * 0.004" else "0.0079 + lineLength * 0.006";
        blazeLightShader =
          pkgs.runCommand "cursor_blaze_light.glsl"
            {
              src = self.file "shaders/cursor_blaze.glsl";
              inherit trailHex accentHex;
            }
            ''
              ${pkgs.python3}/bin/python3 <<'PY'
              import os

              def hex_to_vec4(h):
                  r = int(h[0:2], 16) / 255.0
                  g = int(h[2:4], 16) / 255.0
                  b = int(h[4:6], 16) / 255.0
                  return f"vec4({r:.4f}, {g:.4f}, {b:.4f}, 1.0)"

              trail = hex_to_vec4(os.environ["trailHex"])
              accent = hex_to_vec4(os.environ["accentHex"])

              with open(os.environ["src"]) as f:
                  content = f.read()

              content = content.replace(
                  "const vec4 TRAIL_COLOR = vec4(1.0, 0.725, 0.161, 1.0);",
                  f"const vec4 TRAIL_COLOR = {trail};"
              )
              content = content.replace(
                  "const vec4 TRAIL_COLOR_ACCENT = vec4(1.0, 0., 0., 1.0);",
                  f"const vec4 TRAIL_COLOR_ACCENT = {accent};"
              )
              content = content.replace("saturate(TRAIL_COLOR_ACCENT, 1.5)", "saturate(TRAIL_COLOR_ACCENT, 1.0)")
              content = content.replace("saturate(TRAIL_COLOR, 1.5)", "saturate(TRAIL_COLOR, 1.0)")
              content = content.replace(
                  "sdfCurrentCursor + .002, 0.004",
                  "sdfCurrentCursor + 0.0515, 0.0315"
              )
              content = content.replace("float mod = .007;", "float mod = .003;")
              content = content.replace(
                  "easedProgress * lineLength));",
                  "easedProgress * (${easedProgressFactor})));"
              )

              with open(os.environ["out"], "w") as f:
                  f.write(content)
              PY
            '';
        resolveShader =
          name:
          if name == "cursor_blaze_light" then "${blazeLightShader}" else self.file "shaders/${name}.glsl";
      in
      {
        programs.ghostty = {
          enable = true;
          package = lib.mkDefault (self.dummyPackage pkgs "ghostty");
          clearDefaultKeybinds = true;
          settings = {
            font-size = lib.mkForce self.settings.fontSize;
            font-thicken = lib.mkForce true;
            font-family = [ self.settings.fontFamily ];
            background-opacity = lib.mkForce (
              if self.isLinux && self.linux.isModuleEnabled "desktop.niri" then
                self.settings.blurOpacity
              else
                self.settings.opacity
            );
            background-blur = lib.mkForce true;
            background = lib.mkForce (
              lib.removePrefix "#" (config.nx.preferences.theme.colors.terminal.normalBackgrounds.primary.html)
            );
            working-directory = "home";
            window-inherit-working-directory = true;
            tab-inherit-working-directory = true;
            split-inherit-working-directory = true;

            custom-shader = map resolveShader self.settings.shaders;

            keybind = [
              "ctrl+shift+c=copy_to_clipboard"
              "ctrl+shift+v=paste_from_clipboard"
              "ctrl+shift+t=new_tab"
              "ctrl+shift+w=close_tab:this"
              "ctrl+shift+n=new_window"
              "ctrl+shift+q=quit"
              "ctrl+==increase_font_size:1"
              "ctrl+-=decrease_font_size:1"
              "ctrl+shift+0=reset_font_size"
              "ctrl+shift+,=reload_config"
            ];
          };
        };

        home.sessionVariables = lib.mkIf self.settings.setEnv {
          TERMINAL = "ghostty";
        };
      };

    linux = {
      enabled = config: {
        nx.linux.desktop.niri.blurAppIdsNoXray = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
          "com.mitchellh.ghostty"
        ];
      };
      home =
        config:
        lib.mkIf (self.linux.isModuleEnabled "desktop.niri") {
          programs.niri.settings.window-rules = [
            {
              matches = [ { app-id = "com.mitchellh.ghostty"; } ];
              default-column-width = {
                proportion = 0.33;
              };
            }
          ];
        };
    };
  };
}
