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
  config.user = {
    username = "template";

    fullname = null;

    email = null;

    gpg = null;

    stateVersion = null;

    additionalPackages = [ ];

    allowedUnfreePackages = [ ];

    modules = { };

    specialisations = { };

    settings = { };

    extraSettings = { };

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
