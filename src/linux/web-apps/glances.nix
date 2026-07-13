args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  autoHosts = lib.filterAttrs (
    _: hostCfg: (hostCfg.remote.exposedServices.glances or false) != false
  ) (self.nixOSHosts or { });
in
{
  name = "glances";

  group = "web-apps";
  input = "linux";

  options = {
    additionalHosts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            subdomain = lib.mkOption {
              type = lib.types.str;
            };
            domain = lib.mkOption {
              type = lib.types.str;
            };
          };
        }
      );
      default = { };
      description = "Additional glances instances to include alongside auto-discovered ones.";
    };
  };

  module = {
    linux.enabled =
      config:
      let
        buildFn = config.nx.linux.desktop-modules.web-app.buildWebApp;
        fromAutoHosts = lib.mapAttrsToList (
          profileName: hostCfg:
          let
            val = hostCfg.remote.exposedServices.glances;
            subdomain = if val == true then "glances" else val;
            domain = hostCfg.remote.baseDomain or (hostCfg.remote.address or null);
          in
          {
            label = hostCfg.hostname or profileName;
            inherit subdomain domain;
          }
        ) autoHosts;
        fromAddlHosts = lib.mapAttrsToList (name: host: {
          label = name;
          inherit (host) subdomain domain;
        }) config.nx.linux.web-apps.glances.additionalHosts;
        allHosts = fromAutoHosts ++ fromAddlHosts;
        useHostname = lib.length allHosts > 1;
        allSettings = lib.imap0 (i: host: {
          webapp = if useHostname then "glances-${toString i}" else "glances";
          inherit (host) subdomain domain;
          protocol = "https";
          args = "";
        }) allHosts;
      in
      lib.mkIf (buildFn != null && allHosts != [ ]) {
        nx.linux.desktop.niri.autoTiler.ignoredAppIds = lib.concatMap (s: (buildFn s).appIds) allSettings;
      };

    linux.home =
      { config, additionalHosts, ... }:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/glances.svg"
        }";

        fromAutoHosts = lib.mapAttrsToList (
          profileName: hostCfg:
          let
            val = hostCfg.remote.exposedServices.glances;
            subdomain = if val == true then "glances" else val;
            domain = hostCfg.remote.baseDomain or (hostCfg.remote.address or null);
          in
          {
            label = hostCfg.hostname or profileName;
            inherit subdomain domain;
          }
        ) autoHosts;

        fromAdditionalHosts = lib.mapAttrsToList (name: host: {
          label = name;
          inherit (host) subdomain domain;
        }) additionalHosts;

        allHosts = fromAutoHosts ++ fromAdditionalHosts;
        useHostname = lib.length allHosts > 1;

        allSettings = lib.imap0 (i: host: {
          name = if useHostname then "Glances (${host.label})" else "Glances";
          webapp = if useHostname then "glances-${toString i}" else "glances";
          inherit iconPath;
          inherit (host) subdomain domain;
          categories = [
            "Network"
            "System"
          ];
          protocol = "https";
          args = "";
        }) allHosts;
      in
      {
        home.file = lib.mkMerge (
          map (s: (config.nx.linux.desktop-modules.web-app.buildWebApp s).homeFiles) allSettings
        );
        xdg.desktopEntries = lib.mkMerge (
          map (s: (config.nx.linux.desktop-modules.web-app.buildWebApp s).desktopEntries) allSettings
        );
      };
  };
}
