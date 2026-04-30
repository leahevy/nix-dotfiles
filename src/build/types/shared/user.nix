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

    settings = {
      hasRemoteCommand = mkOption {
        type = types.bool;
        default = true;
        description = "Whether nx has the remote command and nixos-anywhere should be installed";
      };
      generateManCaches = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable man-cache";
      };
      shell = mkOption {
        type = (
          types.enum [
            "fish"
            "bash"
            "zsh"
          ]
        );
        default = "fish";
        description = "Default shell for the user";
      };
      desktopPreference = mkOption {
        type = (
          types.enum [
            "gnome"
            "kde"
          ]
        );
        default = "kde";
        description = "Preference for desktop tools (gnome or KDE)";
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
    };
  };
}
