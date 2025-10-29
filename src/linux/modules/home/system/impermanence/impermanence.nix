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
  namespace = "home";

  settings = {
    directories = [ ];
    files = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.persistence."${self.persist}" = {
        directories = self.settings.directories;
        files = self.settings.files;
      };
    };
}
