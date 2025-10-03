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

  defaults = {
    name = "Immich";
    webapp = "immich";
    iconPath = "${pkgs.immich}/build/www/favicon.png";
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
