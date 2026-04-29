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
    home = config: {
      programs.man = {
        generateCaches = self.user.settings.generateManCaches;
      };
    };
  };
}
