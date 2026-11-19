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
    useGoogleChromium = false;
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
      package = if self.settings.useGoogleChromium then pkgs.chromium else pkgs.ungoogled-chromium;
      program = self.settings.program;
      chromiumArgs = self.settings.args;
      bin = package + "/bin/${program}";

      mkChromiumAppId =
        webAppSettings:
        let
          host =
            if webAppSettings ? localhostPort then
              "127.0.0.1"
            else
              "${webAppSettings.subdomain}.${webAppSettings.domain}";
          path =
            if webAppSettings ? localhostPort then
              ""
            else
              builtins.head (lib.splitString "#" (lib.removePrefix "/" webAppSettings.args));
          pathEncoded = builtins.replaceStrings [ "/" ] [ "_" ] path;
        in
        "chrome-${host}__${pathEncoded}-Default";

      buildWebAppFn =
        config: webAppSettings:
        let
          webAppUrl =
            if webAppSettings ? localhostPort then
              "http://127.0.0.1:${toString webAppSettings.localhostPort}"
            else
              "${webAppSettings.protocol}://${webAppSettings.subdomain}.${webAppSettings.domain}${webAppSettings.args}";
        in
        {
          appIds = [ (mkChromiumAppId webAppSettings) ];
          homeFiles = {
            "${defs.binDir}/${webAppSettings.webapp}-webapp" = {
              executable = true;
              text =
                if webAppSettings ? tokenFile then
                  ''
                    #!/usr/bin/env bash
                    set -euo pipefail

                    DATA_DIR="$HOME/${self.settings.dataBaseDir}/${webAppSettings.webapp}"
                    CACHE_DIR="$HOME/${self.settings.cacheBaseDir}/${webAppSettings.webapp}"
                    ${pkgs.coreutils}/bin/mkdir -p "$DATA_DIR" "$CACHE_DIR"

                    WEBAPP_URL="${webAppUrl}"
                    if [[ -f "$HOME/${webAppSettings.tokenFile}" ]]; then
                      WEBAPP_URL="${webAppUrl}?token=$(${pkgs.coreutils}/bin/cat "$HOME/${webAppSettings.tokenFile}")"
                    fi
                    exec ${bin} --user-data-dir="$DATA_DIR" --disk-cache-dir="$CACHE_DIR" ${chromiumArgs}"$WEBAPP_URL"
                  ''
                else
                  ''
                    #!/usr/bin/env bash
                    set -euo pipefail

                    DATA_DIR="$HOME/${self.settings.dataBaseDir}/${webAppSettings.webapp}"
                    CACHE_DIR="$HOME/${self.settings.cacheBaseDir}/${webAppSettings.webapp}"
                    ${pkgs.coreutils}/bin/mkdir -p "$DATA_DIR" "$CACHE_DIR"

                    exec ${bin} --user-data-dir="$DATA_DIR" --disk-cache-dir="$CACHE_DIR" ${chromiumArgs}"${webAppUrl}"
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

      ifEnabled.linux.security.aide = {
        enabled = config: {
          nx.linux.security.aide.contentDirectoryWatches = [ ".config/chromium/NativeMessagingHosts" ];
          nx.linux.security.aide.excludePathsRegex = [
            "\\.config/chromium/NativeMessagingHosts/.*\\.socket"
          ];
        };
      };

      linux.home = config: {
        home.packages = [ package ];

        home.persistence."${self.persist}" = {
          directories = self.settings.persistenceDirs;
          files = self.settings.persistenceFiles;
        };
      };
    };
}
