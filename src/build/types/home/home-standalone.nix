{ lib, config, ... }:

with lib;

{
  options.user = {
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
    };

    deploymentMode = mkOption {
      type = types.enum [
        "local"
        "develop"
      ];
      default = "develop";
      description = "How this machine consumes the NX configuration";
    };
  };
}
