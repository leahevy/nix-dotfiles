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

    linux.system = config: {
      documentation.man.cache.enable = self.user.settings.generateManCaches;
      documentation.man.cache.generateAtRuntime = self.user.settings.generateManCaches;
    };
  };
}
