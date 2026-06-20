args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "web-app-chromium";

  group = "desktop-modules";
  input = "linux";

  submodules = {
    linux.desktop-modules.web-app = true;
  };

  settings = {
    package = pkgs.ungoogled-chromium;
    program = "chromium";
    args = "--app=";
    persistenceDirs = [
      ".config/chromium"
      ".cache/chromium"
    ];
    persistenceFiles = [
    ];
  };

  module =
    let
      package = self.settings.package;
      program = self.settings.program;
      chromiumArgs = self.settings.args;
      bin = package + "/bin/${program}";

      buildWebAppFn = config: webAppSettings: {
        homeFiles = {
          "${defs.binDir}/${webAppSettings.webapp}-webapp" = {
            executable = true;
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              exec ${bin} ${chromiumArgs}"${webAppSettings.protocol}://${webAppSettings.subdomain}.${webAppSettings.domain}${webAppSettings.args}"
            '';
          };
        };
        desktopEntries = {
          "${webAppSettings.webapp}" = {
            name = webAppSettings.name;
            comment = "${webAppSettings.name} Web-App";
            exec = "${self.binDir}/${webAppSettings.webapp}-webapp %U";
            icon = webAppSettings.iconPath;
            terminal = false;
            categories = webAppSettings.categories;
          };
        };
      };
    in
    {
      linux.enabled = config: {
        nx.linux.desktop-modules.web-app.buildWebApp = buildWebAppFn config;
      };

      linux.home = config: {
        home.packages = [ self.settings.package ];

        home.persistence."${self.persist}" = {
          directories = self.settings.persistenceDirs;
          files = self.settings.persistenceFiles;
        };
      };
    };
}
