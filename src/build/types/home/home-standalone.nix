{ lib, config, ... }:

with lib;

{
  options.user = {
    username = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The username";
    };

    fullname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's full name";
    };

    gpg = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's main gpg key";
    };

    additionalGPGKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional GPG keys for the user";
    };

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's email";
    };

    home = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's home directory";
    };

    stateVersion = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The Nix state version";
    };

    additionalPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages for the user";
    };

    allowedUnfreePackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Unfree packages allowed for the user";
    };

    modules = mkOption {
      type = types.attrsOf (types.attrsOf (types.attrsOf (types.either types.bool types.attrs)));
      default = { };
      description = "Modules to enable for the user, organized by input and group";
    };

    displays = mkOption {
      type = types.submodule {
        options = {
          main = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Main display";
          };
          secondary = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Secondary display";
          };
        };
      };
      default = { };
      description = "Display configuration";
    };

    location = mkOption {
      type = types.submodule {
        options = {
          latitude = mkOption {
            type = types.nullOr types.float;
            default = null;
            description = "Latitude of user's location";
          };
          longitude = mkOption {
            type = types.nullOr types.float;
            default = null;
            description = "Longitude of user's location";
          };
          altitude = mkOption {
            type = types.float;
            default = 0.0;
            description = "Altitude of user's location in meters";
          };
        };
      };
      default = { };
      description = "User's location";
    };

    homeserverDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Domain name of the home server (without protocol)";
    };

    specialisations = mkOption {
      type = types.attrsOf (
        types.attrsOf (types.attrsOf (types.attrsOf (types.either types.bool types.attrs)))
      );
      default = { };
      description = "Named user specialisations with additional user modules to import (experimental feature - only changes configuration, not packages)";
    };

    profileName = mkOption {
      type = types.str;
      description = "The profile directory name";
    };

    settings = mkOption {
      type = types.submodule {
        options = {

          theme = mkOption {
            type = types.nullOr (
              types.enum [
                "red"
                "green"
              ]
            );
            default = null;
            description = "Theme to use for the user";
          };

          desktop = mkOption {
            type = types.nullOr (
              types.enum [
                "gnome"
                "niri"
                "amethyst"
                "yabai"
              ]
            );
            default = null;
            description = "Active desktop environment (or headless)";
          };
          desktopPreference = mkOption {
            type = (
              types.enum [
                "gnome"
                "kde"
              ]
            );
            default = "kde";
            description = "Preference for desktop tools (gnome or KDE)";
          };
          terminal = mkOption {
            type = types.nullOr (
              types.enum [
                "ghostty"
                "kitty"
              ]
            );
            default = "ghostty";
            description = "Terminal application";
          };
        };
      };
      default = { };
      description = "Standalone settings";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional untyped settings to add to the user configuration";
    };

    configuration = mkOption {
      type = types.functionTo (types.functionTo types.attrs);
      default = args: context: { };
      description = "Virtual module configuration function with signature: args@{ ... }: context@{ config, options, ... }: { ... }";
    };
  };
}
