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
    opacity = 0.75;
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
          font-size = self.settings.fontSize;
          font-thicken = true;
          background-opacity = self.settings.opacity;
          background-blur = true;
          background = "000000";

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
