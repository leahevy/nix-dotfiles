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
          ".local/share/keyrings"
        ];
      };
    };
}
