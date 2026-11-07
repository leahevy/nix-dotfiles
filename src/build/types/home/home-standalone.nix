{ lib, config, ... }:

with lib;

{
  options.user = {
    hardware = mkOption {
      type = types.submodule {
        options = {
          cpu = mkOption {
            type = types.nullOr (
              types.enum [
                "intel"
                "amd"
              ]
            );
            default = null;
            description = "CPU type for microcode and CPU-specific configuration";
          };
          gpu = mkOption {
            type = types.nullOr (
              types.enum [
                "nvidia"
                "amd"
              ]
            );
            default = null;
            description = "GPU type for driver and graphics configuration";
          };
          gpuArchitecture = mkOption {
            type = types.nullOr (types.enum [ "pascal" ]);
            default = null;
            description = "GPU microarchitecture, used to select legacy driver branches when required";
          };
        };
      };
      default = { };
      description = "Hardware configuration";
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

      machineType = mkOption {
        type = types.nullOr (
          types.enum [
            "desktop"
            "tablet"
            "laptop"
            "convertible"
            "server"
          ]
        );
        default = null;
        description = "Machine type (or headless)";
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
