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
    dataBaseDir = ".local/share/webapps";
    cacheBaseDir = ".cache/webapps";
    persistenceDirs = [
      ".config/chromium"
      ".cache/chromium"
      ".local/share/webapps"
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

      mkChromiumAppId =
        webAppSettings:
        let
          host = "${webAppSettings.subdomain}.${webAppSettings.domain}";
          path = builtins.head (lib.splitString "#" (lib.removePrefix "/" webAppSettings.args));
          pathEncoded = builtins.replaceStrings [ "/" ] [ "_" ] path;
        in
        "chrome-${host}__${pathEncoded}-Default";

      buildWebAppFn = config: webAppSettings: {
        appIds = [ (mkChromiumAppId webAppSettings) ];
        homeFiles = {
          "${defs.binDir}/${webAppSettings.webapp}-webapp" = {
            executable = true;
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              DATA_DIR="$HOME/${self.settings.dataBaseDir}/${webAppSettings.webapp}"
              CACHE_DIR="$HOME/${self.settings.cacheBaseDir}/${webAppSettings.webapp}"
              ${pkgs.coreutils}/bin/mkdir -p "$DATA_DIR" "$CACHE_DIR"

              exec ${bin} --user-data-dir="$DATA_DIR" --disk-cache-dir="$CACHE_DIR" ${chromiumArgs}"${webAppSettings.protocol}://${webAppSettings.subdomain}.${webAppSettings.domain}${webAppSettings.args}"
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
