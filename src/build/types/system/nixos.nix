{ lib, config, ... }:

with lib;

{
  options.host = {
    hostname = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The hostname of the system";
    };

    ethernetDeviceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The default ethernet device name";
    };

    wifiDeviceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The default wifi device name (not configured per default)";
    };

    nixHardwareModule = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Hardware module to be imported from this list: https://raw.githubusercontent.com/NixOS/nixos-hardware/refs/heads/master/flake.nix";
    };

    kernel = mkOption {
      type = types.submodule {
        options = {
          variant = mkOption {
            type = types.enum [
              "lts"
              "latest"
            ];
            default = "lts";
            description = "The kernel variant to use";
          };
          bootModules = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Kernel modules available in the initial ramdisk during the boot process (boot.initrd.availableKernelModules)";
          };
          initrdModules = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Kernel modules loaded in the initrd (boot.initrd.kernelModules)";
          };
          nixModules = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Kernel modules loaded in the second stage of the boot process (boot.kernelModules)";
          };
          extraModulePackages = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional packages supplying kernel modules (boot.extraModulePackages)";
          };
          resumeDevice = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Explicit kernel resume device path (boot.kernelParams resume=...). When null, auto-detected from disko swap LVs";
          };
        };
      };
      default = { };
      description = "Kernel settings";
    };

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
            type = types.nullOr (types.enum [ "nvidia" ]);
            default = null;
            description = "GPU type for driver and graphics configuration";
          };
          board = mkOption {
            type = types.nullOr (types.enum [ ]);
            default = null;
            description = "Board type for SBC and embedded system configuration";
          };
        };
      };
      default = { };
      description = "Hardware configuration";
    };

    mainUser = mkOption {
      type = types.either types.str types.attrs;
      description = "The main user (profile name or processed config)";
    };

    additionalUsers = mkOption {
      type = types.listOf (types.either types.str types.attrs);
      default = [ ];
      description = "Additional users (profile names or processed configs)";
    };

    extraGroupsToCreate = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional groups to create on the system";
    };

    userDefaults = mkOption {
      type = types.submodule {
        options = {
          groups = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Default groups for users";
          };
          modules = mkOption {
            type = types.attrsOf (types.attrsOf (types.listOf types.str));
            default = { };
            description = "Default modules for users, organized by input and group";
          };
        };
      };
      default = { };
      description = "Default settings for users";
    };

    settings = {
      networking = mkOption {
        type = types.submodule {
          options = {
            wifi = mkOption {
              type = types.submodule {
                options = {
                  enabled = mkOption {
                    type = types.nullOr types.bool;
                    default = null;
                    description = "Whether WiFi is enabled";
                  };
                };
              };
              default = { };
              description = "WiFi settings";
            };
            useNetworkManager = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to enable networkmanager";
            };
          };
        };
        default = { };
        description = "Networking settings";
      };

      system = {
        tmpSize = mkOption {
          type = types.str;
          default = "2G";
          description = "Tmpfs size of /tmp if system/tmp module is enabled";
        };

        timezone = mkOption {
          type = types.str;
          default = "Europe/Berlin";
          description = "System timezone";
        };

        locale = mkOption {
          type = types.submodule {
            options = {
              main = mkOption {
                type = types.str;
                default = "en_GB.UTF-8";
                description = "Main system locale";
              };
              extra = mkOption {
                type = types.str;
                default = "de_DE.UTF-8";
                description = "Additional system locale";
              };
            };
          };
          default = { };
          description = "System locale settings";
        };

        keymap = mkOption {
          type = types.submodule {
            options = {
              x11 = mkOption {
                type = types.submodule {
                  options = {
                    layout = mkOption {
                      type = types.str;
                      default = "us";
                      description = "X11 keyboard layout";
                    };
                    variant = mkOption {
                      type = types.str;
                      default = "";
                      description = "X11 keyboard variant";
                    };
                    options = mkOption {
                      type = types.str;
                      default = "";
                      description = "X11 keyboard options";
                    };
                  };
                };
                default = { };
                description = "X11 keyboard settings";
              };
              console = mkOption {
                type = types.str;
                default = "us";
                description = "Console keyboard layout";
              };
            };
          };
          default = { };
          description = "Keyboard layout settings";
        };

        sound = mkOption {
          type = types.submodule {
            options = {
              pulse = mkOption {
                type = types.submodule {
                  options = {
                    enabled = mkOption {
                      type = types.bool;
                      default = false;
                      description = "Whether PulseAudio is enabled";
                    };
                  };
                };
                default = { };
                description = "PulseAudio settings";
              };
            };
          };
          default = { };
          description = "Sound settings";
        };

        touchpad = mkOption {
          type = types.submodule {
            options = {
              enabled = mkOption {
                type = types.bool;
                default = false;
                description = "Whether touchpad support is enabled";
              };
            };
          };
          default = { };
          description = "Touchpad settings";
        };

        desktop = mkOption {
          type = types.nullOr (
            types.enum [
              "gnome"
              "niri"
            ]
          );
          default = null;
          description = "Active desktop environment (or headless)";
        };

        firmware = mkOption {
          type = types.submodule {
            options = {
              redistributable = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to enable redistributable firmware";
              };
              unfree = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable unfree firmware";
              };
              modeSwitchDevices = mkOption {
                type = types.listOf (
                  types.submodule {
                    options = {
                      device = mkOption {
                        type = types.str;
                        description = "USB device to mode-switch (format: vendor:product)";
                      };
                      flags = mkOption {
                        type = types.str;
                        default = "-K -Q";
                        description = "USB mode switch flags";
                      };
                    };
                  }
                );
                default = [ ];
                description = "USB devices requiring mode switching";
              };
            };
          };
          default = { };
          description = "Firmware settings";
        };

        virtualisation = mkOption {
          type = types.submodule {
            options = {
              enableKVM = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to enable KVM hardware virtualisation support";
              };
            };
          };
          default = { };
          description = "Virtualisation settings";
        };
      };

      sshd = mkOption {
        type = types.submodule {
          options = {
            authorizedKeys = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "SSH authorized keys for users";
            };
          };
        };
        default = { };
        description = "SSH daemon settings";
      };

    };

    impermanence = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable impermanence (ephemeral root filesystem)";
    };

    deploymentMode = mkOption {
      type = types.enum [
        "managed"
        "server"
        "local"
        "develop"
      ];
      default = "develop";
      description = "How this machine consumes the NX configuration: 1) managed: no local repos, updates pushed from outside; 2) server: local nxconfig, no local edits, auto-upgrades; 3) local: local nxconfig, local edits allowed, auto-upgrades; 4) develop: local nxcore + nxconfig via --override-input, auto-upgrades dry-run only";
    };

    isVMHost = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this host acts as a VM host, enabling VM hosting modules and the nx vm command";
    };

    allowVMBuild = mkOption {
      type = types.bool;
      default = true;
      description = "Allow running this NixOS configuration inside a VM";
    };

    vm = mkOption {
      type = types.submodule {
        options = {
          memorySize = mkOption {
            type = types.int;
            default = 2048;
            description = "VM memory size in MiB";
          };
          cores = mkOption {
            type = types.int;
            default = 2;
            description = "Number of virtual CPU cores";
          };
          graphics = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to enable graphical output";
          };
        };
      };
      default = { };
      description = "VM resource configuration for nx vm builds";
    };
  };
}
