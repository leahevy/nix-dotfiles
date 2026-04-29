{ lib, config, ... }:

with lib;

{
  options.user = {
    home-manager = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use home-manager for the user";
    };

    system = {
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

      loginShell = mkOption {
        type = (
          types.enum [
            "fish"
            "bash"
            "zsh"
          ]
        );
        default = "zsh";
        description = "Default login shell for the user";
      };
    };

    settings = {
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
    };
  };
}
