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

    gpg = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's main gpg key";
    };

    email = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's email";
    };

    home = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The user's home directory";
    };

    stateVersion = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The Nix state version";
    };

    additionalPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages for the user";
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

    settings = mkOption {
      type = types.submodule {
        options = { };
      };
      default = { };
      description = "Standalone settings";
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
