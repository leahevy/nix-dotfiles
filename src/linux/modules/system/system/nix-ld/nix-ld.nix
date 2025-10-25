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
  name = "nix-ld";

  group = "system";
  input = "linux";
  namespace = "system";

  defaults = {
    baseLibraries = [ ];
    additionalLibraries = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    {
      # nix-ld is already enabled through build modules.
      programs.nix-ld = {
        libraries = self.settings.baseLibraries ++ self.settings.additionalLibraries;
      };
    };
}
