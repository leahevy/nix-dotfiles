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
  name = "immich";

  defaults = {
    name = "Immich";
    webapp = "immich";
    iconPath = "${pkgs.immich}/build/www/favicon.png";
    categories = [
      "Photography"
      "Graphics"
    ];
    protocol = "https";
    subdomain = "";
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

  configuration =
    context@{ config, options, ... }:
    let
      webApp = self.getModuleConfig "desktop-modules.web-app";
      package = webApp.package;
      program = webApp.program;
      args = webApp.args;

      bin = package + "/bin/${program}";
    in
    {
      home.file.".local/bin/${self.settings.webapp}-webapp" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          exec ${bin} ${args}"${self.settings.protocol}://${self.settings.subdomain}.${self.settings.domain}${self.settings.args}"
        '';
      };

      xdg.desktopEntries = {
        "${self.settings.webapp}" = {
          name = self.settings.name;
          comment = "${self.settings.name} Web-App";
          exec = "${config.home.homeDirectory}/.local/bin/${self.settings.webapp}-webapp %U";
          icon = self.settings.iconPath;
          terminal = false;
          categories = self.settings.categories;
        };
      };
    };
}
