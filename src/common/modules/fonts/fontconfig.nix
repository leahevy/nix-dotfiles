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

  on = {
    home = config: {
      fonts = {
        fontconfig = {
          enable = true;
        };
      };

      home.persistence."${self.persist.home}" = {
        directories = [
          ".cache/fontconfig"
          ".config/fontconfig"
        ];
      };
    };
  };
}
