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
  autoHosts = lib.filterAttrs (
    _: hostCfg: (hostCfg.remote.exposedServices.paperless-ngx or false) != false
  ) (self.nixOSHosts or { });
in
{
  name = "paperless-ngx";

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
      description = "Additional paperless-ngx instances to include alongside auto-discovered ones.";
    };
  };

  module = {
    linux.home =
      { config, additionalHosts, ... }:
      let
        iconPath = "${helpers.packageFile args pkgs.paperless-ngx
          "lib/paperless-ngx/static/paperless/img/logo-dark.png"
        }";

        fromAutoHosts = lib.mapAttrsToList (
          profileName: hostCfg:
          let
            val = hostCfg.remote.exposedServices.paperless-ngx;
            subdomain = if val == true then "paperless-ngx" else val;
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
          name = if multiple then "Paperless-ngx (${host.label})" else "Paperless-ngx";
          webapp = if multiple then "paperless-ngx-${toString i}" else "paperless-ngx";
          inherit iconPath;
          inherit (host) subdomain domain;
          categories = [
            "Office"
            "Viewer"
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
