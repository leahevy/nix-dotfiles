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
  name = "immich";

  group = "web-apps";
  input = "linux";

  settings = {
    name = "Immich";
    webapp = "immich";
    iconPath = "${helpers.packageFile args pkgs.papirus-icon-theme
      "share/icons/Papirus/48x48/apps/multimedia-photo-manager.svg"
    }";
    categories = [
      "Photography"
      "Graphics"
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
    linux.home = config: {
      home.file = (config.nx.linux.desktop-modules.web-app.buildWebApp self.settings).homeFiles;
      xdg.desktopEntries =
        (config.nx.linux.desktop-modules.web-app.buildWebApp self.settings).desktopEntries;
    };
  };
}
