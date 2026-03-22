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
  name = "web-app-chromium";

  group = "desktop-modules";
  input = "linux";

  settings = {
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

  on = {
    home =
      config:
      let
        package = self.settings.package;
        program = self.settings.program;
        chromiumArgs = self.settings.args;
        bin = package + "/bin/${program}";

        buildWebAppFn = webAppSettings: {
          homeFiles = {
            ".local/bin/${webAppSettings.webapp}-webapp" = {
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
              exec = "${config.home.homeDirectory}/.local/bin/${webAppSettings.webapp}-webapp %U";
              icon = webAppSettings.iconPath;
              terminal = false;
              categories = webAppSettings.categories;
            };
          };
        };
      in
      {
        nx.linux.desktop-modules.web-app.buildWebApp = buildWebAppFn;

        home.packages = [ self.settings.package ];

        home.persistence."${self.persist.home}" = {
          directories = self.settings.persistenceDirs;
          files = self.settings.persistenceFiles;
        };
      };
  };
}
