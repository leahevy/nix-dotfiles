{ lib, config, ... }:

with lib;

{
  options.user = {
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
      description = "How this machine consumes the NX configuration: 1) local: local nxconfig, local edits allowed, auto-upgrades; 2) develop: local nxcore + nxconfig via --override-input, auto-upgrades dry-run only";
    };
  };
}
