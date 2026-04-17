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

  module = {
    linux.home = config: {
      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/keyrings"
        ];
      };
    };
  };
}
