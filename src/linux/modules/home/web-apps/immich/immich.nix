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

  assertions = [
    {
      assertion = self.settings.subdomain != null && self.settings.subdomain != "";
      message = "Subdomain required to be set!";
    }
    {
      assertion = self.settings.domain != null && self.settings.domain != "";
      message = "Domain required to be set!";
    }
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

  custom = {
    webAppModule =
      if self.linux.isModuleEnabled "desktop-modules.web-app-qutebrowser" then
        self.importFileFromOtherModuleSameInput {
          inherit args self;
          modulePath = "desktop-modules.web-app-qutebrowser";
        }
      else
        self.importFileFromOtherModuleSameInput {
          inherit args self;
          modulePath = "desktop-modules.web-app-chromium";
        };
  };

  configuration = custom.webAppModule.custom.buildWebApp self.settings;
}
