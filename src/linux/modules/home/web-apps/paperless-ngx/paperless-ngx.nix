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
  name = "paperless-ngx";

  group = "web-apps";
  input = "linux";
  namespace = "home";

  settings = {
    name = "Paperless-ngx";
    webapp = "paperless-ngx";
    iconPath = "${pkgs.paperless-ngx}/lib/paperless-ngx/static/paperless/img/logo-dark.png";
    categories = [
      "Office"
      "Viewer"
    ];
    protocol = "https";
    subdomain = "paperless";
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
