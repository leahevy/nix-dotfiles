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
  # All fields are optional and can be removed if not required for a
  # specific module.

  # Meta information about this module appearing in the module registry.
  meta = {
    name = "<MODULE>";
    description = "";
  };

  # Submodules to import, same syntax as in profiles:
  #   INPUT = { GROUP = { MODULE = true or CONFIG_ATTRIBUTESET, ...}; };
  submodules = { };

  # Variables which will be set as default in self.settings inside the module.
  # Can be overwritten from the profile.
  defaults = { };

  # Custom attributes which can have any value and may be used when the module
  # file is imported via: (self.importFileCustom args FILENAME)
  custom = { };

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

    };
}
