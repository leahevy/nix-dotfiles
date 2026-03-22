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

  on = {
    linux.home = config: {
      home.persistence."${self.persist.home}" = {
        directories = self.settings.home.directories;
        files = self.settings.home.files;
      };
    };

    linux.system = config: {
      environment.persistence."${self.persist.system}" = {
        directories = self.settings.system.directories;
        files = self.settings.system.files;
      };
    };
  };
}
