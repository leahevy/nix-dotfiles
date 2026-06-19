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
  name = "man";

  group = "core";
  input = "build";

  module = {
    standalone = config: {
      programs.man = {
        generateCaches = self.user.settings.generateManCaches;
      };
    };

    integrated = config: {
      programs.man = {
        generateCaches = false;
      };
    };

    linux.system =
      config:
      lib.mkIf self.user.settings.generateManCaches {
        documentation.man.cache.enable = true;
        documentation.man.cache.generateAtRuntime = true;

        environment.persistence."${self.persist}" = {
          directories = [ "/var/cache/man" ];
        };
      };
  };
}
