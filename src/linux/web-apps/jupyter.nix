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

  options = {
    extraPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      description = "Extra Python packages available in the JupyterLab environment.";
    };
    extraTools = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra non-Python tools added to the service PATH.";
    };
  };

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
        nx.linux.services.jupyter.extraWebAppPackages = config.nx.linux.web-apps.jupyter.extraPackages;
        nx.linux.services.jupyter.extraWebAppTools = config.nx.linux.web-apps.jupyter.extraTools;
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
