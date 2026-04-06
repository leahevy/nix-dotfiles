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

    modules = { }; # Attrset or list at GROUP level: { common.shell = [ "bash" "zsh" ]; }

    specialisations = { };

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
        touchpad = {
          enabled = false;
        };
        desktop = "gnome";
      };

      sshd = {
        authorizedKeys = [ ];
      };
    };

    impermanence = false;

    extraSettings = { };

    on = {
      # Overlays — applied unconditionally BEFORE pkgs is created. Cannot reference pkgs.
      # Each value is a list of (final: prev: { }) functions.
      # overlays = [ (final: prev: { ... }) ];

      # Runs for ALL modules (even disabled) in BOTH contexts.
      # Only set config.nx.* options here.
      # init = args@{ lib, self, ... }: context@{ config, options, ... }: { };

      # Runs in system context
      # system = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };

      # Runs in home context (both standalone and integrated)
      # home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };

      # Platform-specific overrides
      # linux = {
      #   overlays = [ (final: prev: { ... }) ];
      #   init = args@{ lib, self, ... }: context@{ config, options, ... }: { };
      #   system = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      #   home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      # };
      # darwin = {
      #   overlays = [ (final: prev: { ... }) ];
      #   init = args@{ lib, self, ... }: context@{ config, options, ... }: { };
      #   system = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      #   home = args@{ lib, pkgs, self, ... }: context@{ config, options, ... }: { };
      # };
    };
  };
}
