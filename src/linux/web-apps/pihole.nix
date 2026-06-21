args@{
  lib,
  pkgs,
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

  settings = {
    name = "Pihole";
    webapp = "pihole";
    categories = [
      "Network"
      "System"
    ];
    protocol = "https";
    subdomain = "pihole";
    args = "/admin";
    domain =
      if self ? user && self.user.isStandalone then
        self.user.homeserverDomain
      else if self ? host then
        self.host.homeserverDomain
      else
        null;
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

  module = {
    linux.enabled =
      config:
      let
        buildFn = config.nx.linux.desktop-modules.web-app.buildWebApp;
        piholeCfg = config.nx.linux.web-apps.pihole;
        mainSettings = {
          webapp = "pihole";
          subdomain = piholeCfg.subdomain;
          domain = piholeCfg.domain;
          protocol = "https";
          args = piholeCfg.args;
        };
        additionalSettings = lib.mapAttrsToList (name: pCfg: {
          webapp = "pihole-${name}";
          subdomain = pCfg.subdomain;
          domain = pCfg.domain;
          protocol = "https";
          args = piholeCfg.args;
        }) piholeCfg.additionalPiholes;
      in
      lib.mkIf (buildFn != null) {
        nx.linux.desktop.niri.autoTiler.ignoredAppIds = lib.concatMap (s: (buildFn s).appIds) (
          [ mainSettings ] ++ additionalSettings
        );
      };

    home =
      config:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/pi-hole.svg"
        }";
        mainSettings = (lib.filterAttrs (name: value: name != "additionalPiholes") self.settings) // {
          inherit iconPath;
        };

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
          map (settings: (config.nx.linux.desktop-modules.web-app.buildWebApp settings).homeFiles) allSettings
        );
        xdg.desktopEntries = lib.mkMerge (
          map (
            settings: (config.nx.linux.desktop-modules.web-app.buildWebApp settings).desktopEntries
          ) allSettings
        );
      };
  };
}
