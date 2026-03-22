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
  name = "keyring";

  group = "gnome";
  input = "linux";

  on = {
    linux.home = config: {
      home.persistence."${self.persist.home}" = {
        directories = [
          ".local/share/keyrings"
        ];
      };
    };
  };
}
