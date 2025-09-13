{
  lib,
  pkgs,
  pkgs-unstable,
  variables,
  helpers,
  defs,
  ...
}:
{
  config.host = {
    configuration =
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
      context@{ config, options, ... }:
      { };
  };
}
