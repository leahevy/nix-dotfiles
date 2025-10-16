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
  name = "fontconfig";

  group = "fonts";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      fonts = {
        fontconfig = {
          enable = true;
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".cache/fontconfig"
          ".config/fontconfig"
        ];
      };
    };
}
