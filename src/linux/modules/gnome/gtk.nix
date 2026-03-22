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
  name = "gtk";

  group = "gnome";
  input = "linux";

  on = {
    linux.home = config: {
      home.persistence."${self.persist.home}" = {
        directories = [
          ".config/gtk-3.0"
        ];
      };
    };
  };
}
