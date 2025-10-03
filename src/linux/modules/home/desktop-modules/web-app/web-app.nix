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

  custom = rec {
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

    buildWebApp = webAppModule.custom.buildWebApp;
  };
}
