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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/keyrings"
        ];
      };
    };
}
