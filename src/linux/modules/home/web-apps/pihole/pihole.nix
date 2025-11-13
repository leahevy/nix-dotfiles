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
  name = "pihole";

  group = "web-apps";
  input = "linux";
  namespace = "home";

  settings = {
    name = "Pihole";
    webapp = "pihole";
    iconPath = "${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/apps/advert-block.svg";
    categories = [
      "Network"
      "System"
    ];
    protocol = "https";
    subdomain = "pihole";
    args = "/admin";
    domain = if self.user.isStandalone then self.user.homeserverDomain else self.host.homeserverDomain;
    additionalPiholes = { };
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
    {
      assertion = lib.all (
        name:
        let
          config = self.settings.additionalPiholes.${name};
        in
        config.subdomain != null && config.subdomain != ""
      ) (lib.attrNames self.settings.additionalPiholes);
      message = "Subdomain required for all additional piholes!";
    }
    {
      assertion = lib.all (
        name:
        let
          config = self.settings.additionalPiholes.${name};
        in
        config.domain != null && config.domain != ""
      ) (lib.attrNames self.settings.additionalPiholes);
      message = "Domain required for all additional piholes!";
    }
  ];

  custom = {
    webAppModule = self.importFileFromOtherModuleSameInput {
      inherit args self;
      modulePath = "desktop-modules.web-app";
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      mainSettings = lib.filterAttrs (name: value: name != "additionalPiholes") self.settings;

      mainWebApp = custom.webAppModule.custom.buildWebApp mainSettings;

      additionalWebApps = lib.mapAttrsToList (
        name: configOverrides:
        custom.webAppModule.custom.buildWebApp (
          mainSettings
          // configOverrides
          // {
            name = "Pihole (${name})";
            webapp = "pihole-${name}";
          }
        )
      ) self.settings.additionalPiholes;

    in
    lib.mkMerge ([ (mainWebApp context) ] ++ (map (webApp: webApp context) additionalWebApps));
}
