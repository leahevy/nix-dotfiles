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
            description = "Theme to use for the host";
          };

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
