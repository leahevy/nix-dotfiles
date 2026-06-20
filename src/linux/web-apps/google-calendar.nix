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
  name = "google-calendar";

  group = "web-apps";
  input = "linux";

  options = {
    pathSuffix = lib.mkOption {
      type = lib.types.str;
      default = "calendar/u/0/r/month";
      description = "URL path appended after https://calendar.google.com/.";
    };
    makeDefault = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Register Google Calendar as the default calendar handler.";
    };
  };

  submodules = {
    linux.desktop-modules.web-app = true;
  };

  module = {
    enabled =
      config:
      lib.mkIf config.nx.linux.web-apps.google-calendar.makeDefault {
        nx.preferences.desktop.programs.calendar = {
          name = lib.mkForce "google-calendar";
          package = lib.mkForce null;
          localBin = lib.mkForce true;
          openCommand = lib.mkForce [ "google-calendar-webapp" ];
          desktopFile = lib.mkForce "google-calendar.desktop";
        };
      };

    linux.home =
      { config, pathSuffix, ... }:
      let
        iconPath = "${helpers.packageFile args config.nx.linux.desktop-modules.web-app.dashboardIcons
          "svg/google-calendar.svg"
        }";
        webAppSettings = {
          name = "Google Calendar";
          webapp = "google-calendar";
          inherit iconPath;
          categories = [ "Office" ];
          protocol = "https";
          subdomain = "calendar";
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
