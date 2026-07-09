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
  name = "web-app";

  group = "desktop-modules";
  input = "linux";

  options = {
    buildWebApp = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.attrs);
      default = null;
      description = "Function to build a web app, returning { homeFiles, desktopEntries, appIds }. Set by the active backend.";
    };
    dashboardIcons = lib.mkOption {
      type = lib.types.package;
      description = "The homarr-labs/dashboard-icons source derivation for use in web-app icon paths.";
    };
  };

  module = {
    init = config: {
      nx.linux.desktop-modules.web-app.dashboardIcons = config.nx.linux.desktop.icons.dashboardIcons;
    };
  };

  assertions = [
    {
      assertion =
        (self.linux.isModuleEnabled "desktop-modules.web-app-chromium")
        || (self.linux.isModuleEnabled "desktop-modules.web-app-qutebrowser");
      message = "Either web-app-chromium or web-app-qutebrowser module must be enabled";
    }
    {
      assertion =
        !(
          (self.linux.isModuleEnabled "desktop-modules.web-app-chromium")
          && (self.linux.isModuleEnabled "desktop-modules.web-app-qutebrowser")
        );
      message = "Only one web-app backend (chromium or qutebrowser) can be enabled at a time";
    }
  ];
}
