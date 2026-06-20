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
  name = "home-assistant";

  group = "web-apps";
  input = "linux";

  settings = {
    name = "Home-Assistant";
    webapp = "home-assistant";
    categories = [
      "Network"
      "System"
      "Utility"
    ];
    protocol = "https";
    subdomain = "";
    args = "";
    domain =
      if self ? user && self.user.isStandalone then
        self.user.homeserverDomain
      else if self ? host then
        self.host.homeserverDomain
      else
        null;
  };

  submodules = {
    linux = {
      desktop-modules = {
        web-app = true;
      };
    };
  };

  assertions = [
    {
      assertion = self.settings.subdomain != null && self.settings.subdomain != "";
      message = "Subdomain required to be set!";
    }
    {
      assertion = self.settings.domain != null && self.settings.domain != "";
      message = "Domain required to be set!";
    }
  ];

  module = {
    linux.home =
      config:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/home-assistant.svg"
        }";
        webAppSettings = self.settings // {
          inherit iconPath;
        };
      in
      {
        home.file = (config.nx.linux.desktop-modules.web-app.buildWebApp webAppSettings).homeFiles;
        xdg.desktopEntries =
          (config.nx.linux.desktop-modules.web-app.buildWebApp webAppSettings).desktopEntries;
      };
  };
}
