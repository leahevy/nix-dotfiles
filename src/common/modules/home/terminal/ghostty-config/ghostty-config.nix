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

  defaults = {
    fontSize = 12;
    opacity = 0.80;
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
        package = lib.mkDefault null;
        settings = {
          font-size = lib.mkForce self.settings.fontSize;
          font-thicken = lib.mkForce true;
          background-opacity = lib.mkForce self.settings.opacity;
          background-blur = lib.mkForce true;
          background = lib.mkForce "000000";

          custom-shader =
            let
              resolveShader = name: self.file "shaders/${name}.glsl";
            in
            map resolveShader self.settings.shaders;
        };
      };

      home.sessionVariables = lib.mkIf self.settings.setEnv {
        TERMINAL = "ghostty";
      };
    };
}
