{ lib, config, ... }:

with lib;

{
  options.all = {
    profileName = mkOption {
      type = types.str;
      description = "The profile directory name";
    };

    addBaseGroup = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically add the base group to the profile";
    };

    allowedUnfreePackages = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Unfree packages allowed for this build";
    };

    additionalPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages for this build";
    };

    modules = mkOption {
      type = types.attrsOf (
        types.attrsOf (
          types.either (types.listOf types.str) (types.attrsOf (types.either types.bool types.attrs))
        )
      );
      default = { };
      description = "Modules to enable for this build, organized by input and group";
    };

    specialisations = mkOption {
      type = types.attrsOf (
        types.attrsOf (types.attrsOf (types.attrsOf (types.either types.bool types.attrs)))
      );
      default = { };
      description = "Named user/system specialisations with additional modules to import";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional untyped settings to add to the configuration";
    };

    profile = mkOption {
      type = types.attrs;
      default = { };
      description = "Event functions (init, enabled, home, system, standalone, integrated + linux/darwin variants). Signature: args -> config -> { }";
    };

  };
}
