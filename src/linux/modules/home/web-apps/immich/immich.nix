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
rec {
  name = "immich";

  group = "web-apps";
  input = "linux";
  namespace = "home";

  settings = {
    name = "Immich";
    webapp = "immich";
    iconPath = "${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/apps/multimedia-photo-manager.svg";
    categories = [
      "Photography"
      "Graphics"
    ];
    protocol = "https";
    subdomain = "";
    args = "";
    domain = if self.user.isStandalone then self.user.homeserverDomain else self.host.homeserverDomain;
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

  custom = {
    webAppModule = self.importFileFromOtherModuleSameInput {
      inherit args self;
      modulePath = "desktop-modules.web-app";
    };
  };

  configuration = custom.webAppModule.custom.buildWebApp self.settings;
}
