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
  name = "google-mail";

  group = "web-apps";
  input = "linux";

  options = {
    pathSuffix = lib.mkOption {
      type = lib.types.str;
      default = "mail/u/0/#inbox";
      description = "URL path appended after https://mail.google.com/.";
    };
    makeDefault = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register Google Mail as the default email handler.";
    };
  };

  submodules = {
    linux.desktop-modules.web-app = true;
  };

  module = {
    enabled =
      config:
      lib.mkIf config.nx.linux.web-apps.google-mail.makeDefault {
        nx.preferences.desktop.programs.emailClient = {
          name = lib.mkForce "google-mail";
          package = lib.mkForce null;
          localBin = lib.mkForce true;
          openCommand = lib.mkForce [ "google-mail-webapp" ];
          desktopFile = lib.mkForce "google-mail.desktop";
        };
      };

    linux.home =
      { config, pathSuffix, ... }:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/gmail.svg"
        }";
        webAppSettings = {
          name = "Google Mail";
          webapp = "google-mail";
          inherit iconPath;
          categories = [
            "Network"
            "Email"
          ];
          protocol = "https";
          subdomain = "mail";
          domain = "google.com";
          args = "/${pathSuffix}";
        };
      in
      {
        home.file = (config.nx.linux.desktop-modules.web-app.buildWebApp webAppSettings).homeFiles;
        xdg.desktopEntries =
          (config.nx.linux.desktop-modules.web-app.buildWebApp webAppSettings).desktopEntries;
      };
  };
}
