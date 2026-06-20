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

  group = "desktop-modules";
  input = "linux";

  options = {
    buildWebApp = lib.mkOption {
      type = lib.types.nullOr (lib.types.functionTo lib.types.attrs);
      default = null;
      description = ''
        Function to build a web app. Takes webAppSettings, returns { homeFiles, desktopEntries }.
        Set by the active backend (qutebrowser or chromium).
      '';
    };
    dashboardIcons = lib.mkOption {
      type = lib.types.package;
      description = "The homarr-labs/dashboard-icons source derivation for use in web-app icon paths.";
    };
  };

  module = {
    init = config: {
      nx.linux.desktop-modules.web-app.dashboardIcons = pkgs.fetchFromGitHub {
        owner = "homarr-labs";
        repo = "dashboard-icons";
        rev = "f222c55843b888a82e9f2fe2697365841cbe6025";
        hash = "sha256-VOWQh8ZadsqNInoXcRKYuXfWn5MK0qJpuYEWgM7Pny8=";
      };
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
