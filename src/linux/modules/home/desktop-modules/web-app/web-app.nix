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

  custom = {
    buildWebApp =
      webAppSettings:
      context@{ config, options, ... }:
      let
        package = self.settings.package;
        program = self.settings.program;
        args = self.settings.args;
        bin = package + "/bin/${program}";
      in
      {
        home.file.".local/bin/${webAppSettings.webapp}-webapp" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            set -euo pipefail

            exec ${bin} ${args}"${webAppSettings.protocol}://${webAppSettings.subdomain}.${webAppSettings.domain}${webAppSettings.args}"
          '';
        };

        xdg.desktopEntries = {
          "${webAppSettings.webapp}" = {
            name = webAppSettings.name;
            comment = "${webAppSettings.name} Web-App";
            exec = "${config.home.homeDirectory}/.local/bin/${webAppSettings.webapp}-webapp %U";
            icon = webAppSettings.iconPath;
            terminal = false;
            categories = webAppSettings.categories;
          };
        };
      };
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
