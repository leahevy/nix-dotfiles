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

  module = {
    linux.home = config: {
      home.persistence."${self.persist}" = {
        directories = [
          ".config/gtk-3.0"
        ];
      };
    };
  };
}
