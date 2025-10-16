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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.persistence."${self.persist}" = {
        directories = [
          ".config/gtk-3.0"
        ];
      };
    };
}
