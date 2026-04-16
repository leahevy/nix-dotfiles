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
  name = "impermanence";

  group = "system";
  input = "linux";

  settings = {
    home = {
      directories = [ ];
      files = [ ];
    };
    system = {
      directories = [ ];
      files = [ ];
    };
  };

  module = {
    linux.home = config: {
      home.persistence."${self.persist}" = {
        directories = self.settings.home.directories;
        files = self.settings.home.files;
      };
    };

    linux.system = config: {
      environment.persistence."${self.persist}" = {
        directories = self.settings.system.directories;
        files = self.settings.system.files;
      };
    };
  };
}
