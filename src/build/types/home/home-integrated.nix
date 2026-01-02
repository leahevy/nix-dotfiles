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

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's email";
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

    home = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's home directory";
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

    home-manager = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use home-manager for the user";
    };

    modules = mkOption {
      type = types.attrsOf (types.attrsOf (types.attrsOf (types.either types.bool types.attrs)));
      default = { };
      description = "Modules to enable for the user, organized by input and group";
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

    system = mkOption {
      type = types.submodule {
        options = {
          createHome = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to create a home directory";
          };

          group = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "The user's primary group";
          };

          extraGroups = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional groups for the user";
          };

          systemdSessionAtBoot = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to start a systemd session at boot";
          };

          isSystemUser = mkOption {
            type = types.bool;
            default = false;
            description = "Whether the user is a system user";
          };

          shell = mkOption {
            type = types.str;
            default = "zsh";
            description = "The user's shell";
          };

        };
      };
      default = { };
      description = "System-level user settings";
    };

    settings = mkOption {
      type = types.submodule {
        options = {
          sshd = mkOption {
            type = types.submodule {
              options = {
                authorizedKeys = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  description = "SSH authorized keys for the user";
                };
              };
            };
            default = { };
            description = "SSH daemon settings";
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
          desktopPreferences = mkOption {
            type = types.submodule {
              options = {
                primary = mkOption {
                  type = types.enum [
                    "gnome"
                    "kde"
                  ];
                  default = "kde";
                  description = "Primary desktop environment preference";
                };
                secondary = mkOption {
                  type = types.enum [
                    "gnome"
                    "kde"
                  ];
                  default = "kde";
                  description = "Secondary desktop environment preference";
                };
                overrides = mkOption {
                  type = types.submodule {
                    options = {
                      primary = mkOption {
                        type = types.attrs;
                        default = { };
                        description = "Overrides for primary desktop preferences";
                      };
                      secondary = mkOption {
                        type = types.attrs;
                        default = { };
                        description = "Overrides for secondary desktop preferences";
                      };
                    };
                  };
                  default = { };
                };
              };
            };
            default = { };
            description = "Desktop environment preferences";
          };
        };
      };
      default = { };
      description = "User settings for modules";
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
