{
  lib,
  pkgs,
  pkgs-unstable,
  variables,
  helpers,
  defs,
  ...
}:
{
  config.host = {

    hostname = "template";

    ethernetDeviceName = null;

    wifiDeviceName = null;

    additionalPackages = [ ];

    nixHardwareModule = null;

    kernel = {
      variant = "lts";
      bootModules = [ ];
      initrdModules = [ ];
      nixModules = [ ];
      extraModulePackages = [ ];
    };

    mainUser = null;

    additionalUsers = [ ];

    extraGroupsToCreate = [ ];

    userDefaults = {
      groups = [ ];
      modules = { };
    };

    stateVersion = null;

    allowedUnfreePackages = [ ];

    modules = { };

    specialisations = { };

    defaultSpecialisation = "Base";

    settings = {
      networking = {
        wifi = {
          enabled = false;
        };
        useNetworkManager = true;
      };

      system = {
        tmpSize = "2G";
        timezone = "Europe/Berlin";
        locale = {
          main = "en_GB.UTF-8";
          extra = "de_DE.UTF-8";
        };
        keymap = {
          x11 = {
            layout = "us";
            variant = "";
          };
          console = "us";
        };
        sound = {
          pulse = {
            enabled = true;
          };
        };
        printing = {
          enabled = false;
        };
        touchpad = {
          enabled = false;
        };
        desktop = {
          gnome = {
            enabled = true;
          };
        };
      };

      sshd = {
        authorizedKeys = [ ];
      };
    };

    impermanence = false;

    extraSettings = { };

    configuration =
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
      context@{ config, options, ... }:
      { };
  };
}
