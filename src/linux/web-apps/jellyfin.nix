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
    _: hostCfg: (hostCfg.remote.exposedServices.jellyfin or false) != false
  ) (self.nixOSHosts or { });
in
{
  name = "jellyfin";

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
      description = "Additional jellyfin instances to include alongside auto-discovered ones.";
    };
  };

  submodules = {
    linux.desktop-modules.web-app = true;
  };

  module = {
    linux.enabled =
      config:
      let
        buildFn = config.nx.linux.desktop-modules.web-app.buildWebApp;
        fromAutoHosts = lib.mapAttrsToList (
          profileName: hostCfg:
          let
            val = hostCfg.remote.exposedServices.jellyfin;
            subdomain = if val == true then "media" else val;
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
        }) config.nx.linux.web-apps.jellyfin.additionalHosts;
        allHosts = fromAutoHosts ++ fromAddlHosts;
        multiple = lib.length allHosts > 1;
        allSettings = lib.imap0 (i: host: {
          webapp = if multiple then "jellyfin-${toString i}" else "jellyfin";
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
          "svg/jellyfin.svg"
        }";

        fromAutoHosts = lib.mapAttrsToList (
          profileName: hostCfg:
          let
            val = hostCfg.remote.exposedServices.jellyfin;
            subdomain = if val == true then "media" else val;
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
        multiple = lib.length allHosts > 1;

        allSettings = lib.imap0 (i: host: {
          name = if multiple then "Jellyfin (${host.label})" else "Jellyfin";
          webapp = if multiple then "jellyfin-${toString i}" else "jellyfin";
          inherit iconPath;
          inherit (host) subdomain domain;
          categories = [
            "Video"
            "AudioVideo"
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
