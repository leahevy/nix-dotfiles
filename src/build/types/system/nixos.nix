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

    isVM = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this host is a virtual machine";
    };

    kernel = mkOption {
      type = types.submodule {
        options = {
          systemdInitrd = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to use Systemd for the initial RAM disk";
          };
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
          addPhysicalModules = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically apply defaults.physicalModules kernel module sets";
          };
          addVMModules = mkOption {
            type = types.bool;
            default = false;
            description = "Automatically apply defaults.vmModules kernel module sets";
          };
          addOpticalDriveModules = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically apply defaults.opticalDriveModules kernel module sets";
          };
          addFilesystemModules = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically apply defaults.filesystemModules kernel module sets";
          };
          defaults = mkOption {
            type = types.submodule {
              options =
                let
                  moduleSet =
                    defaults:
                    types.submodule {
                      options = {
                        classicBootModules = mkOption {
                          type = types.listOf types.str;
                          default = defaults.classicBootModules or [ ];
                        };
                        classicInitrdModules = mkOption {
                          type = types.listOf types.str;
                          default = defaults.classicInitrdModules or [ ];
                        };
                        systemdBootModules = mkOption {
                          type = types.listOf types.str;
                          default = defaults.systemdBootModules or [ ];
                        };
                        systemdInitrdModules = mkOption {
                          type = types.listOf types.str;
                          default = defaults.systemdInitrdModules or [ ];
                        };
                        nixModules = mkOption {
                          type = types.listOf types.str;
                          default = defaults.nixModules or [ ];
                        };
                      };
                    };
                  both = modules: {
                    classicBootModules = modules;
                    systemdBootModules = modules;
                  };
                  bothInitrd = modules: {
                    classicInitrdModules = modules;
                    systemdInitrdModules = modules;
                  };
                in
                {
                  physicalModules = mkOption {
                    type = moduleSet (both [
                      "xhci_pci"
                      "ahci"
                      "usb_storage"
                      "usbhid"
                      "sd_mod"
                    ]);
                    default = { };
                    description = "Common physical hardware kernel modules, applied when addPhysicalModules is true";
                  };
                  vmModules = mkOption {
                    type = moduleSet (bothInitrd [
                      "virtio_pci"
                      "virtio_blk"
                      "virtio_net"
                    ]);
                    default = { };
                    description = "VM kernel modules for virtio compatibility, applied when addVMModules is true";
                  };
                  opticalDriveModules = mkOption {
                    type = moduleSet (both [ "sr_mod" ]);
                    default = { };
                    description = "Optical drive kernel modules, applied when addOpticalDriveModules is true";
                  };
                  filesystemModules = mkOption {
                    type = moduleSet { classicBootModules = [ "btrfs" ]; };
                    default = { };
                    description = "Filesystem kernel modules, applied when addFilesystemModules is true";
                  };
                };
            };
            default = { };
            description = "Default kernel module sets selectively applied via add* options";
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
      type = types.either types.nonEmptyStr types.attrs;
      description = "The main user (profile name or processed config)";
    };

    additionalUsers = mkOption {
      type = types.listOf (types.either types.nonEmptyStr types.attrs);
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

        vmsDataPath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Optional custom VM data directory for nx vm";
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

    remote = mkOption {
      type = types.submodule {
        options = {
          address = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Remote hostname/IP for connecting";
          };
          port = mkOption {
            type = types.port;
            default = 22;
            description = "Remote port for connecting";
          };
          deploymentPort = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Remote port for deployment";
          };
          installPort = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Remote port for installing";
          };
          deploySSHPublicKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "SSH public key for the nx-deployment user; when set the nx-deployment user is created with this key and passwordless sudo is configured, otherwise the main user connects with password-based sudo";
          };
          initrdSSHServicePort = mkOption {
            type = types.port;
            default = 2233;
            description = "Port the SSH service in the initrd listens on, used for remote LUKS unlocking";
          };
          initrdSSHExposedPort = mkOption {
            type = types.port;
            default = 2233;
            description = "Port used in SSH config entries to reach the initrd SSH service from remote";
          };
          initrdSSHHostPrivateKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "SSH host private key for the initrd SSH service. Use a dedicated key generated only for this purpose as it is stored in the Nix store.";
          };
          initrdSSHHostPublicKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "SSH host public key for the initrd SSH service. Must be set when initrdSSHHostPrivateKey is configured; used to auto-populate known_hosts_managed.";
          };
        };
      };
      default = { };
      description = "Remote deployment configuration";
    };
  };
}
