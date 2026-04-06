args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "{{_file_name_}}";
  #description = "";

  group = "{{_lua:extract_group()_}}";
  input = "{{_lua:extract_input()_}}";

  # Attrset: { INPUT.GROUP = { MODULE = true or {...}; }; } or List: { INPUT.GROUP = [ "module1" "module2" ]; }
  submodules = { };

  # Defaults for self.settings, overridable from profile
  settings = { };

  # Typed options at config.nx.INPUT.GROUP.MODULE.*, access via (self.options config).NAME
  options = { };

  # Root-level NixOS/HM options
  rawOptions = { };

  # Unfree package names to allow
  unfree = [ ];

  # Arbitrary data, accessed via self.importFileCustom
  custom = { };

  # warning = "This module is work in progress.";
  # error = "This module is currently broken!";
  # broken = true;

  assertions = [
    {
      assertion = true;
      message = "Test assertion";
    }
  ];

  on = {
    # All modules, both contexts, only config.nx.*, no self.settings
    # init = config: lib.mkIf self.isEnabled { };

    # Enabled only, both contexts
    # enabled = config: { };

    # Enabled, home context
    home = config: {
      home.persistence."${self.persist}" = {
        directories = [ ];
        files = [ ];
      };
    };

    # Enabled, system context
    # system = config: {
    #   environment.persistence."${self.persist}" = {
    #     directories = [ ];
    #     files = [ ];
    #   };
    # };

    # standalone = config: { };
    # integrated = config: { };

    # Before pkgs creation, no pkgs access
    # overlays = [ (final: prev: { ... }) ];

    # linux = {
    #   overlays = [ (final: prev: { ... }) ];
    #   init = config: { };
    #   enabled = config: { };
    #   home = config: { };
    #   system = config: { };
    #   standalone = config: { };
    #   integrated = config: { };
    # };
    # darwin = { ... };
  };
}
