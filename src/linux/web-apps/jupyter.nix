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
  name = "jupyter";
  group = "web-apps";
  input = "linux";

  description = "JupyterLab web-app launcher";

  submodules = {
    linux.services.jupyter = true;
    linux.desktop-modules.web-app = true;
  };

  module = {
    linux.enabled =
      config:
      let
        buildFn = config.nx.linux.desktop-modules.web-app.buildWebApp;
        port = config.nx.linux.services.jupyter.port;
      in
      lib.mkIf (buildFn != null) {
        nx.linux.desktop.niri.autoTiler.ignoredAppIds =
          (buildFn {
            localhostPort = port;
            webapp = "jupyter";
          }).appIds;
      };

    linux.home =
      { config, ... }:
      let
        port = config.nx.linux.services.jupyter.port;
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/jupyter.svg"
        }";
        appSettings = {
          name = "JupyterLab";
          webapp = "jupyter";
          localhostPort = port;
          tokenFile = config.nx.linux.services.jupyter.tokenFile;
          inherit iconPath;
          categories = [
            "Development"
            "Science"
          ];
        };
      in
      {
        home.file = (config.nx.linux.desktop-modules.web-app.buildWebApp appSettings).homeFiles;
        xdg.desktopEntries =
          (config.nx.linux.desktop-modules.web-app.buildWebApp appSettings).desktopEntries;
      };
  };
}
