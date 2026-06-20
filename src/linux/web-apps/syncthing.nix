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
    _: hostCfg: (hostCfg.remote.exposedServices.syncthing or false) != false
  ) (self.nixOSHosts or { });
in
{
  name = "syncthing";

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
      description = "Additional syncthing instances to include alongside auto-discovered ones.";
    };
  };

  module = {
    linux.home =
      { config, additionalHosts, ... }:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/syncthing.svg"
        }";

        fromAutoHosts = lib.mapAttrsToList (
          profileName: hostCfg:
          let
            val = hostCfg.remote.exposedServices.syncthing;
            subdomain = if val == true then "syncthing" else val;
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
        localSyncthingEnabled = config.nx.common.services.syncthing.enable;
        useHostname = localSyncthingEnabled || lib.length allHosts > 1;

        allSettings = lib.imap0 (i: host: {
          name = if useHostname then "Syncthing (${host.label})" else "Syncthing";
          webapp = if useHostname then "syncthing-${toString i}" else "syncthing";
          inherit iconPath;
          inherit (host) subdomain domain;
          categories = [ "Network" ];
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
