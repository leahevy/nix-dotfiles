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
{
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
