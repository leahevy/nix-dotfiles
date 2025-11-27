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
  name = "ghostty-config";

  group = "terminal";
  input = "common";
  namespace = "home";

  settings = {
    fontSize = 12;
    opacity = 0.95;
    shaders = [
      #"cursor_blaze"
      "cursor_smear"
    ];
    setEnv = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      programs.ghostty = {
        enable = true;
        package = lib.mkDefault (self.dummyPackage "ghostty");
        clearDefaultKeybinds = true;
        settings = {
          font-size = lib.mkForce self.settings.fontSize;
          font-thicken = lib.mkForce true;
          font-family = [ "DejaVuSansM Nerd Font Mono" ];
          background-opacity = lib.mkForce self.settings.opacity;
          background-blur = lib.mkForce true;
          background = lib.mkForce "000000";

          custom-shader =
            let
              resolveShader = name: self.file "shaders/${name}.glsl";
            in
            map resolveShader self.settings.shaders;

          keybind = [
            "ctrl+shift+c=copy_to_clipboard"
            "ctrl+shift+v=paste_from_clipboard"
            "ctrl+shift+t=new_tab"
            "ctrl+shift+w=close_tab:this"
            "ctrl+shift+n=new_window"
            "ctrl+shift+q=quit"
            "ctrl+==increase_font_size:1"
            "ctrl+-=decrease_font_size:1"
            "ctrl+0=reset_font_size"
            "ctrl+shift+,=reload_config"
          ];
        };
      };

      home.sessionVariables = lib.mkIf self.settings.setEnv {
        TERMINAL = "ghostty";
      };
    };
}
