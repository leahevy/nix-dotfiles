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
  name = "impermanence";

  group = "system";
  input = "linux";
  namespace = "system";

  settings = {
    directories = [ ];
    files = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      environment.persistence."${self.persist}" = {
        directories = self.settings.directories;
        files = self.settings.files;
      };
    };
}
