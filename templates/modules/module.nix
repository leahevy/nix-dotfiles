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
  namespace = "{{_lua:extract_namespace()_}}";

  # Submodules to import, same syntax as in profiles:
  #   INPUT = { GROUP = { MODULE = true or CONFIG_ATTRIBUTESET, ...}; };
  submodules = { };

  # Variables which will be set as default in self.settings inside the module.
  # Can be overwritten from the profile.
  settings = { };

  # List of strings with unfree package names to allow in the build.
  unfree = [ ];

  # Custom attributes which can have any value and may be used when the module
  # file is imported via: (self.importFileCustom args FILENAME)
  custom = { };

  # Optional warning message to display during build evaluation
  # warning = "This module is work in progress.";

  # Optional error message to throw and prevent build
  # error = "This module is currently broken!";

  # Optional boolean to mark module as broken (prevents build)
  # broken = true;

  # Assertions to check in a build for this module.
  # Should be used to validate self.settings before the build config is evaluated.
  assertions = [
    {
      assertion = true;
      message = "Test assertion";
    }
  ];

  # The actual build configuration of the module.
  configuration =
    context@{ config, options, ... }:
    {
      # For system modules
      environment.persistence."${self.persist}" = {
        directories = [ ];
        files = [ ];
      };

      # For home-manager modules
      home.persistence."${self.persist}" = {
        directories = [ ];
        files = [ ];
      };
    };
}
