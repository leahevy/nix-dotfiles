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
  name = "web-app";

  defaults = {
    package = pkgs.chromium;
    program = "chromium";
    args = "--app=";
    persistenceDirs = [
      ".config/chromium"
      ".cache/chromium"
    ];
    persistenceFiles = [
    ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = [ self.settings.package ];

      home.persistence."${self.persist}" = {
        directories = self.settings.persistenceDirs;
        files = self.settings.persistenceFiles;
      };
    };
}
