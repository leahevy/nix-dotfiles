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

  configuration =
    context@{ config, options, ... }:
    let
      mainSettings = lib.filterAttrs (name: value: name != "additionalPiholes") self.settings;

      allSettings = [
        mainSettings
      ]
      ++ lib.mapAttrsToList (
        name: configOverrides:
        mainSettings
        // configOverrides
        // {
          name = "Pihole (${name})";
          webapp = "pihole-${name}";
        }
      ) self.settings.additionalPiholes;
    in
    {
      home.file = lib.mkMerge (
        map (
          settings: (config.nx.linux.desktop-modules.web-app.buildWebApp settings context).homeFiles
        ) allSettings
      );
      xdg.desktopEntries = lib.mkMerge (
        map (
          settings: (config.nx.linux.desktop-modules.web-app.buildWebApp settings context).desktopEntries
        ) allSettings
      );
    };
}
