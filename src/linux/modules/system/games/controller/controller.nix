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
  name = "controller";

  group = "games";
  input = "linux";
  namespace = "system";

  defaults = {
    enableXone = true;
  };

  configuration =
    context@{ config, options, ... }:
    {
      hardware.xone.enable = self.settings.enableXone;
    };
}
