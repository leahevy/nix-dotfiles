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
let
  home-assistant-frontend = pkgs.python3Packages.buildPythonPackage rec {
    pname = "home_assistant_frontend";
    version = "20250903.5";
    format = "wheel";

    src = pkgs.fetchPypi {
      inherit version format;
      pname = "home_assistant_frontend";
      dist = "py3";
      python = "py3";
      hash = "sha256-aN6OLdDwBpXkeiswK/bpz+q5J4QG/WzeJwk37xRYJm8=";
    };

    doCheck = false;
  };
in
rec {
  name = "home-assistant";

  defaults = {
    name = "Home-Assistant";
    webapp = "home-assistant";
    iconPath = "${home-assistant-frontend}/lib/python3.12/site-packages/hass_frontend/static/icons/favicon-192x192.png";
    categories = [
      "Network"
      "System"
      "Utility"
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
