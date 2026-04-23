{ lib, config, ... }:

with lib;

{
  options.main = {
    stateVersion = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The Nix state version";
    };

    location = mkOption {
      type = types.submodule {
        options = {
          latitude = mkOption {
            type = types.nullOr types.float;
            default = null;
            description = "Latitude of the profile's geo-location";
          };
          longitude = mkOption {
            type = types.nullOr types.float;
            default = null;
            description = "Longitude of profiles's geo-location";
          };
          altitude = mkOption {
            type = types.float;
            default = 0.0;
            description = "Altitude of profile's geo-location in meters";
          };
        };
      };
      default = { };
      description = "Profile's geo-location";
    };

    homeserverDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Domain name of the home server (without protocol)";
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

    settings = {
      theme = mkOption {
        type = types.nullOr (
          types.enum [
            "red"
            "orange"
            "yellow"
            "green"
            "cyan"
            "blue"
            "magenta"
            "purple"
            "white"
          ]
        );
        default = null;
        description = "Theme to use for this build";
      };
    };
  };
}
