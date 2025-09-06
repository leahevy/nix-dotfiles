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
