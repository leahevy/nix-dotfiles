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

    additionalPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages for the host";
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
              "hardened"
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
        };
      };
      default = { };
      description = "Kernel settings";
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

    stateVersion = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The NixOS state version";
    };

    allowedUnfreePackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Unfree packages allowed for the host";
    };

    modules = mkOption {
      type = types.attrsOf (types.attrsOf (types.attrsOf (types.either types.bool types.attrs)));
      default = { };
      description = "System modules to enable, organized by input and group";
    };

    specialisations = mkOption {
      type = types.attrsOf (
        types.attrsOf (types.attrsOf (types.attrsOf (types.either types.bool types.attrs)))
      );
      default = { };
      description = "Named system specialisations with additional system modules to import";
    };

    defaultSpecialisation = mkOption {
      type = types.str;
      default = "Base";
      description = "Default system specialisation to enable or the Base specialisation";
    };

    profileName = mkOption {
      type = types.str;
      description = "The profile directory name";
    };

    settings = mkOption {
      type = types.submodule {
        options = {

          networking = mkOption {
            type = types.submodule {
              options = {
                wifi = {
                  enabled = mkOption {
                    type = types.nullOr types.bool;
                    default = null;
                    description = "Whether WiFi is enabled";
                  };
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

          system = mkOption {
            type = types.submodule {
              options = {
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

                locale = {
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

                keymap = {
                  x11 = {
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
                  };
                  console = mkOption {
                    type = types.str;
                    default = "us";
                    description = "Console keyboard layout";
                  };
                };

                sound.pulse.enabled = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether PulseAudio is enabled";
                };

                printing.enabled = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether printing support is enabled";
                };

                touchpad.enabled = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether touchpad support is enabled";
                };

                desktop.gnome.enabled = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Whether GNOME desktop is enabled";
                };
              };
            };
            default = { };
            description = "System settings";
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
      };
      default = { };
      description = "Host settings";
    };

    impermanence = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable impermanence (ephemeral root filesystem)";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional untyped settings to add to the host configuration";
    };

    configuration = mkOption {
      type = types.functionTo (types.functionTo types.attrs);
      default = args: context: { };
      description = "Virtual module configuration function with signature: args@{ ... }: context@{ config, options, ... }: { ... }";
    };
  };
}
